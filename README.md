# HttpDiff

## Overview
This is a CLI tool for comparing two JSON files containing an array of
a request/response pairs. It takes in two files, prints out the method
and base URL of the requests in each file and prompts the user to
select one from the first file and one from the second file. Then the
differences between the chosen requests are computed by the program will be output to the terminal.

The differences that the tool computes are
   - deletions
   - insertions
   - updates 
   - reorders (Headers, JSON keys etc.)
   
The tool assumes that both files supplied are the same structure as the example files. 

Executable can be built with escript using `mix deps.get` then `mix escript.build`

The examples directory contains the given example files aswell as a file containing one of the requests from the examples (config_13.3.7.json), and another file (config_gen.json) containing multiple GPT generated variations on that request for demo and testing purposes.


## Useage
Once the repository has been cloned and built with mix then it can be used as follows:

```shell
./http_diff ./examples/13.3.7_.json ./examples/13.4.0_.json  
```

The following will be printed to the terminal:

```shell
[0] GET https://status.thebank.teller.engineering/status.json
[1] GET https://thebank.teller.engineering/api/apps/A3254414/configuration
[2] POST https://thebank.teller.engineering/api/accesstokens/usernameandpassword

[0] GET https://thebank.teller.engineering/api/apps/A3254415/configuration
[1] GET https://status.thebank.teller.engineering/status.json
[2] POST https://thebank.teller.engineering/api/sectrace/verify
[3] POST https://thebank.teller.engineering/api/accesstokens/usernameandpassword

First Choice => 
```

To compare both configuration requests you can enter 1 and then 0

```shell
First Choice => 1
Second Choice => 0
```

The results of the program will be printed to the terminal and the choices will be presented again if you want to compare another request from the files.


