# MT4TradeCopier #
Copies and Replicates trade from Master MT4 to follower MT4 clients, using C# console program to act as a distribution server.
Original code was done with Visual Studio 2017. In 2022, this project can be re-written in Golang as a REST service, or using  websockets.

## TerminalFileCopier Deploy ##
TCM will be placed in Master Trader terminal window.
TCC will be placed in each Follower's terminal window.
When Master places a trade:
- a trade file is generated.
- TerminalFileCopier detects file change in Master directory, and copies file to all Follower's directory
- TCC reads the file and checks if it a new instruction to Open a new trade or Close a current trade.


## TermStarter ##
TermStarter is a WinForms program to provide an adminstrative panel to activate or start follower's client terminals. 

For each follower's terminals, it will also ProcessFindByWindowTitle to poll whether the follower terminal is alive.

<img src="https://github.com/jiunnhwa/MT4TradeCopier/blob/main/TermStarter/Screenshot/TermStarter%20-%20Window%20-%20Start.PNG" width=70% >
