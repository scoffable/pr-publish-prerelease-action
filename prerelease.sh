#!/bin/bash

# Input Variables
GITHUB_TOKEN="$1"
COMMIT_MESSAGE_KEYWORD="$2"
FEATURE_BRANCH="$3"
TRUNK_BRANCH="$4"

# Preconditions and initial checks
HEAD_COMMIT_MESSAGE=$(git log -1 --no-merges --pretty=%B)

echo "Branch: $FEATURE_BRANCH"
echo "Head Commit Message: $HEAD_COMMIT_MESSAGE"

# Exit if the commit message doesn't meet the specific keyword
if [[ "$HEAD_COMMIT_MESSAGE" != "$COMMIT_MESSAGE_KEYWORD"* ]]; then
  echo "No commit with the keyword found. Exiting."
  exit 0
fi

# Sanitize Branch Name
SANITIZED_BRANCH=$(echo "$FEATURE_BRANCH" | tr -cd '[:alnum:]\n' | tr '[:upper:]' '[:lower:]')

echo "Sanitizing branch name: $SANITIZED_BRANCH"

# Determine the Main Version
MAIN_VERSION=$(git describe --tags --abbrev=0 $(git merge-base origin/$TRUNK_BRANCH HEAD))
echo "Common trunk version: $MAIN_VERSION"

# Determine the next sequence number for `A`
LATEST_TAG=$(git describe --tags --match "$MAIN_VERSION-$SANITIZED_BRANCH.*" --abbrev=0 2>/dev/null)
echo "Latest branch tag: $LATEST_TAG"

if [[ $LATEST_TAG ]]; then
  LAST_A=${LATEST_TAG##*.}
  NEXT_A=$((LAST_A + 1))
else
  NEXT_A=1
fi

PRE_RELEASE_VERSION="$MAIN_VERSION-$SANITIZED_BRANCH.$NEXT_A"

# Update and commit `pom.xml`
if [ -f "pom.xml" ]; then
  echo "Updating pom.xml with prerelease version: $PRE_RELEASE_VERSION"
  sed -i '' "s|<version>.*</version>|<version>$PRE_RELEASE_VERSION</version>|" pom.xml
  git add pom.xml
  git commit -m "Update pom.xml to $PRE_RELEASE_VERSION"
fi

# Authenticate and create the prerelease using GitHub CLI
echo "Authenticating with GitHub CLI using GITHUB_TOKEN..."
echo "$GITHUB_TOKEN" | gh auth login --with-token

echo "Creating prerelease with version: $PRE_RELEASE_VERSION"
gh release create "$PRE_RELEASE_VERSION" --prerelease --notes "Automated prerelease: $PRE_RELEASE_VERSION" --target "$BRANCH"
