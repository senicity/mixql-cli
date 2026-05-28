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
## MIXQL CLI
This is the official CLI helper for MixQL (Mix Query Language) which was created to handle all aspects of hashing, salting and one-way encryption. This allows you to communicate with the MixQL server directly and get responses using the query language.

### Usage
To use the CLI, simply run it as a bash command in your terminal:

```bash
bash mixql.sh
```

### Defaults
By default, the CLI uses host ```localhost``` and port ```7272``` which are the official MixQL default options.

#### Changing defaults
To change defaults on runtime, simply add the following to your command line when running MixQL, use ```-h``` followed by the hostname of your choice to change the host and ```-p``` to change the port that the CLI will attempt to connect to. 

```bash
bash mixql.sh -h mixql.demo.senicity.com -p 9797
```

### Agent Integration
The MixQL CLI provides an interactive REPL interface that can be used by AI agents and automated systems. For detailed information on agent usage patterns, best practices, and examples, see [AGENTS.md](AGENTS.md).

Key features for agents:
- **Parameterized queries**: Support for placeholders like `:param_name`
- **REPL interface**: Interactive `mixql>` prompt
- **Error handling**: Color-coded success/error responses
- **Interactive usage**: Designed for manual or agent-driven interaction

#### Interactive Agent Usage
```bash
# Start the interactive CLI
bash mixql.sh

# Then type queries at the mixql> prompt:
# mixql> SELECT SHA1(:input) AS hash
# Enter value for "input": hello
```