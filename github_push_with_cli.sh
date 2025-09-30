#!/bin/bash

# GitHub CLI Push Script for NotedCore
echo "🚀 NotedCore GitHub Repository Setup"
echo "====================================="

# Check if gh is authenticated
if ! gh auth status &>/dev/null; then
    echo "❌ You need to authenticate with GitHub first!"
    echo ""
    echo "Run: gh auth login"
    echo ""
    echo "Then run this script again."
    exit 1
fi

echo "✅ GitHub CLI authenticated"
echo ""

# Ask for repository visibility
echo "Repository visibility:"
echo "1) Public (recommended for open source)"
echo "2) Private (for proprietary code)"
read -p "Choose (1 or 2): " VISIBILITY

if [ "$VISIBILITY" = "2" ]; then
    VIS_FLAG="--private"
    VIS_TEXT="private"
else
    VIS_FLAG="--public"
    VIS_TEXT="public"
fi

echo ""
echo "📝 Creating $VIS_TEXT repository 'Noted' on GitHub..."

# Create repository and push
gh repo create Noted $VIS_FLAG \
    --description "Advanced Medical Transcription & Clinical Intelligence System" \
    --source=. \
    --remote=origin \
    --push

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Success! Your repository is now live!"
    echo ""
    
    # Get the repository URL
    REPO_URL=$(gh repo view --json url -q .url)
    echo "🌐 Repository URL: $REPO_URL"
    echo ""
    
    # Open in browser
    read -p "Would you like to open the repository in your browser? (y/n): " OPEN_BROWSER
    if [ "$OPEN_BROWSER" = "y" ] || [ "$OPEN_BROWSER" = "Y" ]; then
        gh repo view --web
    fi
    
    echo ""
    echo "📊 Repository Statistics:"
    gh repo view
    
    echo ""
    echo "🎯 Next Steps:"
    echo "1. Add topics: gh repo edit --add-topic medical,healthcare,transcription,ai,swift"
    echo "2. Enable features: gh repo edit --enable-issues --enable-wiki"
    echo "3. Add collaborators: gh repo add-collaborator USERNAME"
    echo "4. Create first issue: gh issue create --title 'Initial Setup' --body 'Setup development environment'"
    
else
    echo ""
    echo "❌ Failed to create repository. Common issues:"
    echo "1. Repository name already exists"
    echo "2. Network connectivity issues"
    echo "3. GitHub API rate limits"
    echo ""
    echo "Try manually: gh repo create Noted --public"
fi