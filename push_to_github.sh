#!/bin/bash

# Script to push NotedCore to GitHub repository
# Usage: ./push_to_github.sh [username]

echo "🚀 NotedCore GitHub Push Script"
echo "================================"

# Get GitHub username
if [ -z "$1" ]; then
    read -p "Enter your GitHub username: " GITHUB_USER
else
    GITHUB_USER=$1
fi

echo ""
echo "📋 Instructions:"
echo "1. First, create a new repository on GitHub:"
echo "   - Go to: https://github.com/new"
echo "   - Repository name: Noted"
echo "   - Description: Advanced Medical Transcription & Clinical Intelligence System"
echo "   - Make it Public or Private as desired"
echo "   - DO NOT initialize with README, .gitignore, or license"
echo ""
read -p "Press Enter when you've created the repository on GitHub..."

echo ""
echo "🔗 Setting up remote repository..."

# Remove existing remote if it exists
git remote remove origin 2>/dev/null

# Add new remote
git remote add origin "https://github.com/${GITHUB_USER}/Noted.git"

echo "✅ Remote added: https://github.com/${GITHUB_USER}/Noted.git"

# Show current branch
CURRENT_BRANCH=$(git branch --show-current)
echo "📍 Current branch: $CURRENT_BRANCH"

# Push to GitHub
echo ""
echo "📤 Pushing to GitHub..."
git push -u origin "$CURRENT_BRANCH"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Successfully pushed to GitHub!"
    echo ""
    echo "🎉 Your repository is now available at:"
    echo "   https://github.com/${GITHUB_USER}/Noted"
    echo ""
    echo "📱 Next steps:"
    echo "   1. Visit your repository on GitHub"
    echo "   2. Add collaborators if needed (Settings > Manage access)"
    echo "   3. Set up GitHub Actions for CI/CD (optional)"
    echo "   4. Configure branch protection rules (Settings > Branches)"
    echo "   5. Add topics for better discoverability"
    echo ""
    echo "🔒 Security recommendations:"
    echo "   - Enable vulnerability alerts (Settings > Security)"
    echo "   - Set up code scanning"
    echo "   - Configure secret scanning"
    echo "   - Add CODEOWNERS file if working with a team"
else
    echo ""
    echo "❌ Push failed. Common issues:"
    echo "   1. Authentication: You may need to set up a Personal Access Token"
    echo "      - Go to: https://github.com/settings/tokens"
    echo "      - Generate new token with 'repo' scope"
    echo "      - Use token as password when prompted"
    echo ""
    echo "   2. Repository doesn't exist: Make sure you created it on GitHub"
    echo ""
    echo "   3. Wrong username: Check the repository URL"
    echo ""
    echo "To retry with a different username:"
    echo "   ./push_to_github.sh <your-github-username>"
fi