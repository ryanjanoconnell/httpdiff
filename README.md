# HttpDiff

This is a CLI tool for comparing two JSON files containing an array of
a request/response pairs. It takes in two files, prints out the method
and base URL of the requests in each file and prompts the user to
select one from the first file and one from the second file. Then the
differences between the chosen requests are computed by the program will be output to the terminal.

The differences that the tool computes are
   - deletions
   - insertions
   - updates 
   - reorders 

The tool has Jason as its only dependency. Jason is used for parsing the files into a Jason.OrderedObject so that reorders can be tracked.

The tool assumes that both files supplied are the same structure as the example files.

Executable can be built with escript using mix deps.get then mix escript.build.

The examples directory contains the given example files aswell as a file containing one of the requests from the examples (config_13.3.7.json), and another file (config_gen.json) containing multiple GPT generated variations on that request for demo and testing purposes.

