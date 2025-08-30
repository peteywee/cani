#!/bin/bash
# A script to initialize a git repo, commit the initial structure,
# create a GitHub repo, and push the code.

# ---CONFIGURATION---
# !!! IMPORTANT: Change this to the name you want for your GitHub repository.
REPO_NAME="cani"
# !!! Your GitHub username.
GITHUB_USER="peteywee"


# Step 1: Initialize a local Git repository and make the first commit
echo "Initializing local git repository..."
git init -b main
git add .
git commit -m "feat: initial project structure"

# Step 2: Create a new repository on GitHub using the GitHub CLI
# This will create a public repository. Change --public to --private if you need a private one.
echo "Creating GitHub repository: $GITHUB_USER/$REPO_NAME"
gh repo create "$REPO_NAME" --public --source=. --remote=origin

# Step 3: Push your local repository to GitHub
echo "Pushing initial commit to GitHub..."
git push -u origin main

echo "✅ Successfully created and pushed to https://github.com/$GITHUB_USER/$REPO_NAME"
