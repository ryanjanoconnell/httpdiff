# HttpDiff

This is a CLI tool for comparing two JSON files containing an array of
a request/response pairs. It takes in two files, prints out the method
and base URL of the requests in each file and prompts the user to
select one from the first file and one from the second file. Then the
differences computed by the program will be output to the terminal.

The differences that the tool computes are
   - deletions
   - insertions
   - updates (change in the value of a key)
   - reorders (change in the position of a  key)

The program has Jason as its only dependency. Jason is used for parsing the files into a Jason.OrderedObject so that reorders can be tracked.

