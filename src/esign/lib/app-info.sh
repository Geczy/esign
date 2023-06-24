#!/bin/bash

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
  local description=$(echo "$response" | jq -r '.results[0].description')
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
  "description": "$description",
  "developerName": "$developer_name",
  "icon": "$icon",
  "type": $app_type,
  "iconURL": "$icon_url"
}
EOF
  )

  echo "$updated_json"
}
