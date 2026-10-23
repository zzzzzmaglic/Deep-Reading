#!/bin/zsh

set -u

script_directory="${0:A:h}"
repository_directory="${script_directory:h:h}"
output_directory="${repository_directory}/supabase/.debug/reading-report"
mode="${1:-follow}"

mkdir -p "$output_directory"

export_line() {
  local line="$1"
  [[ "$line" == *'"event":"reading_report_writing_prompt_capture"'* ]] || return 0

  local payload="${line#*\[Info\] }"
  local event
  event=$(jq -r '.event // empty' <<< "$payload" 2>/dev/null) || return 0
  [[ "$event" == "reading_report_writing_prompt_capture" ]] || return 0

  local captured_at capture_id article_id captured_tag filename temporary_file
  captured_at=$(jq -r '.capturedAt' <<< "$payload")
  capture_id=$(jq -r '.captureId' <<< "$payload")
  article_id=$(jq -r '.articleId' <<< "$payload")
  captured_tag=$(sed -E 's/[-:]//g; s/\.[0-9]+Z$/Z/' <<< "$captured_at")
  filename="${captured_tag}_${article_id}_${capture_id}_writing-system-prompt.md"
  temporary_file="${output_directory}/.${filename}.tmp.$$"

  [[ -f "${output_directory}/${filename}" ]] && return 0
  jq -er '.request.messages[] | select(.role == "system") | .content' <<< "$payload" > "$temporary_file" || {
    rm -f "$temporary_file"
    return 0
  }
  chmod 600 "$temporary_file"
  mv "$temporary_file" "${output_directory}/${filename}"
  echo "Exported ${output_directory}/${filename}"
}

follow_container() {
  local container_id="$1"
  local log_arguments=(logs)
  if [[ "$mode" == "--once" ]]; then
    log_arguments+=("$container_id")
  else
    log_arguments+=(--follow --since 2s "$container_id")
  fi
  docker "${log_arguments[@]}" 2>&1 | while IFS= read -r line; do
    export_line "$line"
  done
}

if [[ "$mode" == "--once" ]]; then
  container_id=$(docker ps --filter 'name=supabase_edge_runtime' --format '{{.ID}}' | head -1)
  [[ -n "$container_id" ]] || exit 0
  follow_container "$container_id"
  exit 0
fi

while true; do
  container_id=$(docker ps --filter 'name=supabase_edge_runtime' --format '{{.ID}}' | head -1)
  if [[ -z "$container_id" ]]; then
    sleep 2
    continue
  fi
  follow_container "$container_id"
  sleep 1
done
