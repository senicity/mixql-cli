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
   - Secure hashing (SHA-1, MD5)
   - Base64 encoding
   - Cryptographic salt generation
   - Encryption key generation
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

## Related Resources

- [MixQL Server Documentation](https://senicity.com)
- [MixQL Query Language Reference](https://senicity.com/docs/mixql)
- [Security Best Practices](https://senicity.com/docs/security)