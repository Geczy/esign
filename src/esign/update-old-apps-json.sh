#!/bin/bash

display_progress_bar() {
  local width=40
  local filled_length=$((width * counter / total_apps))
  local empty_length=$((width - filled_length))

  # Create the progress bar string
  local progress_bar="["
  progress_bar+="$(printf '#%.0s' $(seq 1 "$filled_length"))"
  progress_bar+="$(printf ' %.0s' $(seq 1 "$empty_length"))"
  progress_bar+="]"

  # Calculate the percentage complete
  local percentage=$((counter * 100 / total_apps))

  # Display the progress bar and percentage
  printf "\rProgress: %3d%% %s" "$percentage" "$progress_bar"
}

get_app_info() {
  local bundle_id=$1

  # Make the search request
  local search_url="https://itunes.apple.com/lookup?bundleId=$bundle_id"
  local response=$(curl -s "$search_url")

  # Check for errors in the response
  local error_message=$(echo "$response" | grep -o '"errorMessage":"[^"]*' | sed 's/"errorMessage":"//')
  if [[ -n "$error_message" ]]; then
    echo "Error: $error_message"
    return 1
  fi

  # Check if results[0] exists
  local exists=$(echo "$response" | jq -r '.results[0]')
  if [[ "$exists" == "null" ]]; then
    echo "Error: No results found for the given bundleID: $bundle_id"
    return 1
  fi

  # Extract the app information from the response
  local app_name=$(echo "$response" | jq -r '.results[0].trackName')
  local developer_name=$(echo "$response" | jq -r '.results[0].artistName')
  local icon=$(echo "$response" | jq -r '.results[0].artworkUrl512')
  local icon_url=$(echo "$response" | jq -r '.results[0].artworkUrl512')
  local primary_genre_name=$(echo "$response" | jq -r '.results[0].primaryGenreName')

  # Set the app_type based on the primary genre name
  if [[ "$primary_genre_name" == "Games" ]]; then
    app_type="2"
  else
    app_type="1"
  fi

  # Create the JSON object
  local updated_json=$(
    cat <<EOF
{
  "name": "$app_name",
  "developerName": "$developer_name",
  "icon": "$icon",
  "type": $app_type,
  "iconURL": "$icon_url"
}
EOF
  )

  echo "$updated_json"
}

# Read the input JSON file
input_file="src/esign/apps.json"
input_json=$(cat "$input_file")

# Parse the input JSON and loop through each app
apps=$(echo "$input_json" | jq -c '.apps[]')
updated_apps=""

# Progress bar
counter=0
total_apps=$(echo "$input_json" | jq -r '.apps | length')

while IFS= read -r app; do
  counter=$((counter + 1))
  display_progress_bar

  name=$(echo "$app" | jq -r '.name')
  if [[ -z "$name" ]]; then
    echo "Error: Invalid name for app in input JSON."
    continue
  fi

  bundle_id=$(echo "$app" | jq -r '.realBundleID')
  if [[ -z "$bundle_id" ]]; then
    echo "Error: Invalid bundleID for app '$name' in input JSON."
    continue
  fi

  # Call the get_app_info function for each app
  updated_info=$(get_app_info "$bundle_id")
  if [[ $? -ne 0 ]]; then
    echo ""
    echo "Warning: Failed to retrieve app information for '$name' (bundleID: $bundle_id). Using the original input."
    echo ""
    updated_apps+="$app,"
    continue
  fi

  # Append the updated app info to the updated_apps string
  updated_apps+="$(echo "$app" | jq --argjson updated_info "$updated_info" '. + $updated_info'),"
done <<<"$apps"

echo ""

# Remove the trailing comma from the updated_apps string
updated_apps=${updated_apps%,}

# Create the final JSON object with the updated app information
updated_json=$(echo "$input_json" | jq --argjson updated_apps "[$updated_apps]" '.apps = $updated_apps')

# if updated json is empty exit
if [[ -z "$updated_json" ]]; then
  echo "Error: Failed to update the input JSON."
  exit 1
fi

# Write the updated JSON to a new file
output_file="src/esign/apps.json"
echo "$updated_json" >"$output_file"
