# MT4TradeCopier #
Copies and Replicates trade from Master MT4 to follower MT4 clients, using C3 as a proxy server.

## TerminalFileCopier Deploy ##
TCM will be placed in Master Trader terminal window.
TCC will be placed in each Follower's terminal window.
When Master places a trade:
- a trade file is generated.
- TerminalFileCopier detects file change in Master directory, and copies file to all Follower's directory
- TCC reads the file and checks if it a new instruction to Open a new trade or Close a current trade.
