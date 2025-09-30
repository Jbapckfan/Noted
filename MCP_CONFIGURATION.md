# MCP Server Configuration Guide

## Overview

Model Context Protocol (MCP) servers enhance NotedCore with additional AI capabilities. This guide covers the installation and configuration of MCP servers for use with Claude Desktop.

## Installed MCP Servers

### 1. Filesystem Server
**Purpose**: Manage audio recordings, exports, and medical documents

**Package**: `@modelcontextprotocol/server-filesystem`

**Configuration**:
```json
{
  "filesystem": {
    "command": "npx",
    "args": [
      "-y",
      "@modelcontextprotocol/server-filesystem",
      "/Users/jamesalford/Documents/NotedCore",
      "/Users/jamesalford/Desktop"
    ]
  }
}
```

**Use Cases**:
- Access and manage patient audio recordings
- Export medical notes to files
- Read/write documentation templates
- Manage app configuration files

### 2. Memory Server
**Purpose**: Maintain context across sessions and remember medical terminology

**Package**: `@modelcontextprotocol/server-memory`

**Configuration**:
```json
{
  "memory": {
    "command": "npx",
    "args": [
      "-y",
      "@modelcontextprotocol/server-memory"
    ]
  }
}
```

**Use Cases**:
- Remember patient context between sessions
- Store frequently used medical terms
- Maintain provider preferences
- Cache common diagnoses and treatments

### 3. SQLite Server
**Purpose**: Local database for patient records and medical notes

**Package**: `incubyte-sqlite-mcp-server`

**Configuration**:
```json
{
  "sqlite": {
    "command": "npx",
    "args": [
      "-y",
      "incubyte-sqlite-mcp-server",
      "--db-path",
      "/Users/jamesalford/Documents/NotedCore/medical_notes.db"
    ]
  }
}
```

**Database Schema**:
```sql
-- Patients table
CREATE TABLE patients (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    mrn TEXT UNIQUE,
    date_of_birth DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Encounters table
CREATE TABLE encounters (
    id INTEGER PRIMARY KEY,
    patient_id INTEGER,
    encounter_date TIMESTAMP,
    chief_complaint TEXT,
    transcription TEXT,
    summary TEXT,
    note_type TEXT,
    FOREIGN KEY (patient_id) REFERENCES patients(id)
);

-- Medical notes table
CREATE TABLE medical_notes (
    id INTEGER PRIMARY KEY,
    encounter_id INTEGER,
    note_type TEXT,
    content TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (encounter_id) REFERENCES encounters(id)
);
```

### 4. Brave Search Server
**Purpose**: Medical reference and drug information lookup

**Package**: `@skanda-yutori/server-brave-search`

**Configuration**:
```json
{
  "brave-search": {
    "command": "npx",
    "args": [
      "-y",
      "@skanda-yutori/server-brave-search"
    ],
    "env": {
      "BRAVE_API_KEY": "YOUR_API_KEY_HERE"
    }
  }
}
```

**Getting API Key**:
1. Visit https://brave.com/search/api/
2. Sign up for a free account
3. Generate API key
4. Add to configuration

**Use Cases**:
- Look up drug interactions
- Search medical guidelines
- Verify diagnoses information
- Find treatment protocols

### 5. GitHub Server
**Purpose**: Version control for templates and documentation

**Package**: `@modelcontextprotocol/server-github`

**Configuration**:
```json
{
  "github": {
    "command": "npx",
    "args": [
      "-y",
      "@modelcontextprotocol/server-github"
    ],
    "env": {
      "GITHUB_TOKEN": "YOUR_TOKEN_HERE"
    }
  }
}
```

**Getting GitHub Token**:
1. Go to https://github.com/settings/tokens
2. Click "Generate new token (classic)"
3. Select scopes: `repo`, `read:user`
4. Generate and copy token
5. Add to configuration

**Use Cases**:
- Version control medical templates
- Share documentation improvements
- Track configuration changes
- Collaborate on clinical protocols

## Complete Configuration File

Location: `/Users/jamesalford/Library/Application Support/Claude/claude_desktop_config.json`

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "/Users/jamesalford/Documents/NotedCore",
        "/Users/jamesalford/Desktop"
      ]
    },
    "memory": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-memory"
      ]
    },
    "sqlite": {
      "command": "npx",
      "args": [
        "-y",
        "incubyte-sqlite-mcp-server",
        "--db-path",
        "/Users/jamesalford/Documents/NotedCore/medical_notes.db"
      ]
    },
    "brave-search": {
      "command": "npx",
      "args": [
        "-y",
        "@skanda-yutori/server-brave-search"
      ],
      "env": {
        "BRAVE_API_KEY": "YOUR_BRAVE_API_KEY"
      }
    },
    "github": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-github"
      ],
      "env": {
        "GITHUB_TOKEN": "YOUR_GITHUB_TOKEN"
      }
    }
  }
}
```

## Installation Steps

### 1. Install NPM Packages
```bash
# Install all MCP servers
npm install -g @modelcontextprotocol/server-filesystem
npm install -g @modelcontextprotocol/server-memory
npm install -g incubyte-sqlite-mcp-server
npm install -g @skanda-yutori/server-brave-search
npm install -g @modelcontextprotocol/server-github
```

### 2. Configure Claude Desktop
1. Close Claude Desktop completely
2. Edit the configuration file at the location above
3. Add your API keys
4. Save the file
5. Restart Claude Desktop

### 3. Verify Installation
After restarting Claude, you should see the MCP servers listed in the bottom of the Claude interface.

## Usage Examples

### Filesystem Operations
```
"Read the latest transcription file from NotedCore"
"Save this medical note to the Desktop"
"List all audio recordings from today"
```

### Database Queries
```
"Show all patients seen this week"
"Find encounters with chest pain as chief complaint"
"Get the last 5 medical notes for patient MRN 12345"
```

### Medical Search
```
"Search for drug interactions between aspirin and warfarin"
"Find current guidelines for hypertension treatment"
"Look up side effects of metformin"
```

### Memory Operations
```
"Remember this patient prefers detailed explanations"
"What abbreviations have we used today?"
"Recall the last diagnosis for similar symptoms"
```

## Troubleshooting

### MCP Servers Not Showing
1. Ensure Claude Desktop is completely closed
2. Check configuration file syntax (valid JSON)
3. Verify npm packages are installed globally
4. Check console for errors: View → Developer → Developer Tools

### Permission Issues
```bash
# Fix npm permissions
sudo chown -R $(whoami) ~/.npm
sudo chown -R $(whoami) /usr/local/lib/node_modules
```

### Server Crashes
1. Check API keys are valid
2. Ensure file paths exist
3. Verify network connectivity
4. Check server logs in Claude's developer console

## Security Considerations

1. **API Keys**: Store securely, never commit to version control
2. **File Access**: Limit filesystem server to specific directories
3. **Database**: Use encrypted storage for sensitive medical data
4. **Network**: Use VPN for medical searches if required by policy

## Advanced Configuration

### Custom Database Path
```json
"sqlite": {
  "command": "npx",
  "args": [
    "-y",
    "incubyte-sqlite-mcp-server",
    "--db-path",
    "/custom/path/to/database.db"
  ]
}
```

### Multiple Filesystem Roots
```json
"filesystem": {
  "command": "npx",
  "args": [
    "-y",
    "@modelcontextprotocol/server-filesystem",
    "/path/one",
    "/path/two",
    "/path/three"
  ]
}
```

### Environment Variables
```json
"server-name": {
  "command": "npx",
  "args": ["..."],
  "env": {
    "CUSTOM_VAR": "value",
    "API_ENDPOINT": "https://api.example.com"
  }
}
```

## Future Enhancements

Potential MCP servers for medical applications:
- **FHIR Server**: Healthcare data exchange
- **ICD-10 Server**: Diagnosis coding
- **CPT Server**: Procedure coding
- **Drug Database Server**: Comprehensive medication information
- **Medical Literature Server**: PubMed/research access

## Support

For MCP-specific issues:
- Check [MCP Documentation](https://modelcontextprotocol.io)
- Visit [MCP GitHub](https://github.com/modelcontextprotocol)
- Ask in Claude Desktop support

For NotedCore integration:
- See [DEVELOPMENT.md](DEVELOPMENT.md)
- Check GitHub issues
- Contact development team