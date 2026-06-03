```

███╗   ███╗██╗██╗  ██╗ ██████╗ ██╗     
████╗ ████║██║╚██╗██╔╝██╔═══██╗██║     
██╔████╔██║██║ ╚███╔╝ ██║   ██║██║     
██║╚██╔╝██║██║ ██╔██╗ ██║▄▄ ██║██║     
██║ ╚═╝ ██║██║██╔╝ ██╗╚██████╔╝███████╗
╚═╝     ╚═╝╚═╝╚═╝  ╚═╝ ╚══▀▀═╝ ╚══════╝
                                       
// -- Powered by:

┏┓┏┓┳┓┳┏┓┳┏┳┓┓┏
┗┓┣ ┃┃┃┃ ┃ ┃ ┗┫
┗┛┗┛┛┗┻┗┛┻ ┻ ┗┛
               
// --> https://senicity.com
// --
```

# MixQL CLI Agents Guide

## Overview

The MixQL CLI is a command-line interface for interacting with MixQL (Mix Query Language) servers. MixQL is designed for secure data operations including hashing, salting, and one-way encryption. This CLI provides a REPL (Read-Eval-Print Loop) interface for executing MixQL queries against a running MixQL server.

## Architecture

The CLI operates as a TCP client that connects to a MixQL server. The architecture follows this flow:

```
User Input → CLI (mixql.sh) → TCP Connection → MixQL Server → Response → CLI → User Output
```

## Core Features

### 1. Interactive REPL Interface
- **Prompt**: `mixql>`
- **Exit command**: Type `exit` to quit
- **Real-time feedback**: Color-coded success/error responses

### 2. Parameterized Queries
MixQL supports parameterized queries using colon-prefixed placeholders. The protocol sends the query on the first line followed by parameter values on subsequent lines:

**Query format**:
```sql
SELECT SHA1(:input) AS hash
```

**Parameter format** (sent on separate lines after the query):
```
value1
value2
```

The CLI automatically detects placeholders and prompts for values:
```
mixql> SELECT SHA1(:input) AS hash

Enter value for "input": hello
```

### 3. Connection Management
- **Default**: `localhost:7272`
- **Customization**: Use `-h` for host and `-p` for port flags
- **TCP-based**: Uses `netcat` (nc) for communication

### 4. Error Handling
- **Success**: Green ✅ indicator with response
- **Error**: Red ❌ indicator with error details

## Usage Examples

### Basic Connection
```bash
bash mixql.sh
```

### Custom Server Connection
```bash
bash mixql.sh -h mixql.demo.senicity.com -p 9797
```

### Query Examples

1. **Simple query**:
```
mixql> CREATE UUID
```

2. **Parameterized query**:
```
mixql> SELECT SHA1(:input) AS hash
Enter value for "input": hello
```

3. **Complex operations**:
```
mixql> SELECT SHA1(CONCAT(:user, NOW())) AS hash
Enter value for "user": admin
```

4. **Multiple parameters**:
```
mixql> SELECT SHA1(CONCAT(:a, :b)) AS hash
Enter value for "a": foo
Enter value for "b": bar
```

## Agent Integration

### For AI/Agent Systems
The MixQL CLI provides an interactive REPL interface that AI agents and automated systems can use for:

1. **Data Security Operations**:
   - Secure hashing (SHA-256, SHA-512, SHA-1, MD5)
   - HMAC-SHA256 keyed hashing
   - Argon2id password hashing and verification
   - Base64 encoding
   - Cryptographic salt generation
   - Encryption key generation
   - AES-256-CBC encryption/decryption (with KEY, SALT, PEPPER)
   - AES-256-GCM authenticated encryption/decryption (recommended)
   - UUID generation

2. **Interactive Usage**:
   The CLI is designed as an interactive REPL. Agents should:
   - Start the CLI with `bash mixql.sh`
   - Type queries at the `mixql>` prompt
   - Provide parameter values when prompted
   - Type `exit` to quit

3. **Script Integration**:
   For automated workflows, consider:
   - Using the MixQL server directly via TCP sockets
   - Creating wrapper scripts that manage the interactive session
   - Implementing proper error handling for network operations

## Best Practices for Agents

1. **Connection Pooling**: Reuse connections for multiple queries
2. **Error Recovery**: Implement retry logic for network issues
3. **Parameter Sanitization**: Validate input before sending to server
4. **Logging**: Log all cryptographic operations for audit trails
5. **Timeout Handling**: Set appropriate timeouts for long-running operations

## Security Considerations

- **Network Security**: Use TLS/SSL for production deployments
- **Access Control**: Implement proper authentication/authorization
- **Input Validation**: Validate all user inputs before processing
- **Audit Logging**: Maintain logs of all cryptographic operations

## Troubleshooting

### Common Issues

1. **Connection refused**: Ensure MixQL server is running on specified host/port
2. **Timeout errors**: Check network connectivity and server load
3. **Query syntax errors**: Verify MixQL query syntax with server documentation
4. **Parameter issues**: Ensure all placeholders have corresponding values

### Debug Mode
For debugging, you can modify the `mixql.sh` script to add verbose logging:
```bash
# Add to mixql.sh for debugging
echo "DEBUG: Sending query: $QUERY" >&2
echo "DEBUG: To server: $HOST:$PORT" >&2
```

# MixQL Server - Authentication Context

## Authentication Implementation Overview

The MixQL server now includes **optional simple authentication** for added security. This is a basic username/password authentication system that provides access control for the TCP-based query server.

## Key Authentication Features

### 1. **Optional Authentication**
- Authentication is **disabled by default** (`auth_enabled=false`)
- Can be enabled via config file or environment variable
- When disabled, all requests are automatically authenticated

### 2. **Simple Authentication Protocol**
- Clients must send `AUTH username:password` as the first command
- Credentials validated against configured `auth_users` map
- Returns `AUTH_FAILED` if authentication fails
- After successful authentication, normal query processing continues

### 3. **Configuration Options**
- **Config file**: `auth_enabled=true/false`, `auth_users=user1:pass1,user2:pass2`
- **Environment variable**: `SERVER_AUTH_ENABLED=true/false`
- **Default users**: `admin:secret123`, `user:password456` (in example config)

## Security Characteristics

### **Simple Security Model**
- **Purpose**: Basic access control, not cryptographic security
- **Credentials**: Stored in plain text in config file
- **Transport**: No encryption (plain TCP)
- **Use case**: Internal networks, development environments, basic access restriction

### **Limitations**
- Passwords stored in plain text
- No transport encryption
- No password hashing
- No session management (authenticate per request)
- No rate limiting or brute force protection

## Usage Examples

### With Authentication Enabled:
```bash
# Authenticate first, then query
echo -e "AUTH admin:secret123\nSELECT SHA1(:input) AS hash\nhello" | nc localhost 7272
```

### Without Authentication:
```bash
# Direct query (when auth_enabled=false)
echo -e "SELECT SHA1(:input) AS hash\nhello" | nc localhost 7272
```

## Implementation Details

### Source Code Location:
- **Authentication logic**: `src/server.cpp` → `handle_client()` function
- **Configuration**: `config/config.h` → `Config` struct
- **Config file**: `config/config.ini` or `config/config.example.ini`

### Authentication Flow:
1. Client connects via TCP
2. Server checks `auth_enabled` flag
3. If enabled: expects `AUTH username:password` command
4. Validates against `auth_users` map
5. If valid: removes AUTH line, processes query
6. If invalid: returns `AUTH_FAILED`, closes connection

## Recommendations

### **When to Use This Authentication:**
- Internal/private networks
- Development and testing environments
- Basic access control for non-sensitive data
- As a simple gatekeeper before implementing stronger security

### **When to Use Additional Security:**
- Production environments with sensitive data
- Public-facing servers
- When transport encryption is needed (add TLS/SSL)
- When password security is critical (add hashing)

## Recent Changes
- Added optional simple authentication system
- Updated documentation in AGENTS.md and README.md
- Configuration supports both file and environment variables
- Authentication integrated into client handler flow