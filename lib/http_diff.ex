defmodule HttpDiff do

  @moduledoc """
  CLI tool for identifying changes between two JSON files containing an array of HTTP
  request/response pairs.

  When I refer to objects in the comments I really mean decoded JSON objects, so either a Jason.OrderedObject or a map depending on
  the options used in Jason.decode.
  
  The main function of the module is diff/4 which takes in the patches computed so far, the currenct path and two Jason.OrderedObjects or maps
  and returns a collection of patches that describe how the first object could be transformed into
  the second object. A patch can describe a deletion of key/value pair, an insertion of a key/value pair
  an update of the value of an already existing key or a reordering of the keys in the objects.

  A patch is a map that contains the type of patch, path to the patch, the old value and the new value.
  For example if a key/value pair in a nested object was deleted then its patch would look like this:
  
  iex> %{type: :delete, path: ["address" "postcode"], old_value: 10222, new_value: nil}
  
  ## Struct
  The struct of the module is how the different patches that are computed by diff/4 are stored for
  ease of printing output to the terminal. It contains MapSets for the different types of patches. MapSets
  were used instead of lists so that testing can be done with == rather than worrying about the order of
  the patches.
  """
  ###################### General Diffing #######################
  
  defstruct reorders: MapSet.new([]),
            updates: MapSet.new([]),
            deletes: MapSet.new([]),
            inserts: MapSet.new([])
  
  @doc """
  Takes in the patches computed so far and adds a new patch

  Note that the old_value and new_value for :reorder patches are the index of the
  key in the objects.
  """
  def add_patch(patches = %HttpDiff{}, type, path, old_value, new_value) do
    patch = %{type: type, path: path, old_value: old_value, new_value: new_value}
    case type do
      :reorder -> %{patches | reorders: MapSet.put(patches.reorders, patch)}
      :update ->  %{patches | updates: MapSet.put(patches.updates, patch)}
      :delete ->  %{patches | deletes: MapSet.put(patches.deletes, patch)}
      :insert ->  %{patches | inserts: MapSet.put(patches.inserts, patch)}
      _ -> raise("Unknown patch type: #{type}")
    end
  end

  def key_union(a, b) do
    keys_a = Enum.map(a, fn {k, _v} -> k end)
    keys_b = Enum.map(b, fn {k, _v} -> k end)
    Enum.uniq(keys_a ++ keys_b)
  end

  @doc """
  If the index of the key in the object a and the index of the key in object b are
  not equal then a :reorder patch is recorded.
  """
  def check_and_handle_reorder(patches = %HttpDiff{}, path, key, index_in_a, index_in_b) do
    if index_in_a != index_in_b do
      add_patch(patches, :reorder, path ++ [key], index_in_a, index_in_b)
    else
      patches
    end
  end

  @doc """
  If both values corresponding to key are objects (maps or Jason.OrderedObject) then
  no patches are recorded. If they are not objects and are not equal then an update patch
  is recorded. Otherwise no patches recorded.

  Note that if the value in a is not an object and the value in b is an object then
  the new_value in the patch map will be an object. The keys in the new object will not have
  their own patch, instead there will be a single patch for the entire new object.
  """
  def check_and_handle_update(patches = %HttpDiff{}, path, key, val_a, val_b) do
    case {val_a, val_b} do
      {%{}, %{}} ->
	patches
      {val_a, val_b} when val_a != val_b ->
	add_patch(patches, :update, path ++ [key], val_a, val_b)
      _ ->
	patches
    end
  end

  @doc """
  If both values are objects then dive into nested objects and diff them
  """
  def check_and_handle_recur(patches = %HttpDiff{}, path, key, val_a, val_b) do
    case {val_a, val_b} do
      {%Jason.OrderedObject{}, %Jason.OrderedObject{}} ->
	diff(patches, path ++ [key], val_a, val_b)
      {%{}, %{}} ->
	diff(patches, path ++ [key], val_a, val_b)
      _ ->
	patches
    end
  end


  @doc """
  This is the main function used by the tool.
  
  It takes in the patches so far, the current path, and two Jason.OrderedObjects and then recursively computes
  and records patches. The function traverses the union of the keys in a and b and:
  
  - records a deletion if a key is in a but not b
  - records an insertion if a key is in b but not a
  - records an update if a key is in both a and b but the corresponding values are not equal and not objects
  - records a reorder if the index of the key in a is not equal to the index of the key in b

  If the key is present in both objects and the corresonding values are both objects then the path is updated and
  a recursive call is made.

  A HttpDiff struct that contains all of the computed patches indexed by their type is returned

  If maps are supplied then any reorderings are ignored. A HttpDiff struct will be returned but the MapSet
  corresponding to :reorders will be empty..
  """
  def diff(patches = %HttpDiff{}, path, a = %Jason.OrderedObject{}, b = %Jason.OrderedObject{}) do
    key_union(a, b)
    |> Enum.reduce(patches, fn key, patches ->
      index_in_a = Enum.find_index(a, fn {k, _v} -> k == key end)
      index_in_b = Enum.find_index(b, fn {k, _v} -> k == key end)
      case {Access.get(a, key, :not_found), Access.get(b, key, :not_found)} do
	{:not_found, val_b} ->
	  add_patch(patches, :insert, path ++ [key], nil, val_b)
	{val_a, :not_found} ->
	  add_patch(patches, :delete, path ++ [key], val_a, nil)
	{val_a, val_b} ->
	  patches
	  |> check_and_handle_update(path, key, val_a, val_b)
	  |> check_and_handle_reorder(path, key, index_in_a, index_in_b)
	  |> check_and_handle_recur(path, key, val_a, val_b)	  
      end
    end)
  end

  def diff(patches = %HttpDiff{}, path, a, b) when is_map(a) and is_map(b) do
    key_union(a, b)
    |> Enum.reduce(patches, fn key, patches ->
      case {Access.get(a, key, :not_found), Access.get(b, key, :not_found)} do
	{:not_found, val_b} ->
	  add_patch(patches, :insert, path ++ [key], nil, val_b)
	{val_a, :not_found} ->
	  add_patch(patches, :delete, path ++ [key], val_a, nil)
	{val_a, val_b} ->
	  patches
	  |> check_and_handle_update(path, key, val_a, val_b)
	  |> check_and_handle_recur(path, key, val_a, val_b)	  
      end
    end)
  end

  @doc """
  Calls diff/4 with a fresh HttpDiff structure and empty path.

  If one or more of the values is not a map or Jason.OrderedObject then it records an update if the
  arguements are equal, or else records no patch. This covers the case where when one request body is
  not JSON and the other is JSON, or other such cases.
  """
  def diff(a, b) when is_map(a) and is_map(b), do: diff(%HttpDiff{}, [], a, b)

  def diff(a, b) when a != b do
    %HttpDiff{} |> add_patch(:update, [], a, b)
  end

  def diff(_a, _b), do: %HttpDiff{}
  
  ########################### Diffing for HTTP req/res pairs with same shape as example files  #################################

  @doc """
  This function is used to compute patches for different parts of the supplied request/responses.

  The decoded JSON will not always be in a form that is appropriate for diff/4, so an extraction function is
  supplied to describe how to retrieve the part of the request/response that you want to diff and also to perhaps
  transform it into something more appropriate.

  For example, the headers in the example files are arrays of objects. It is more complicated to diff arrays
  since you need a way to identify which entries are the same (though you could use the name field of the objects in the
  header case however). Instead the header array is extracted and then transformed into an object with keys corresponding
  to the name field and value corresponding to the value field. Then this new object can be passed to diff/4.

  Note that the objects passed to this function will be a Jason.OrderedObject consisting of a single
  request and response pair. ie a single element from the arrary in the example JSON files.
  """
  def diff_with_extraction(a, b, extraction_fn) do
    val_a = extraction_fn.(a)
    val_b = extraction_fn.(b)
    diff(val_a, val_b)
  end
  
  def diff_version(http1, http2) do
    diff_with_extraction(http1, http2, fn http -> get_in(http, ["version"]) end)
  end

  def diff_method(http1, http2) do
    diff_with_extraction(http1, http2, fn http -> get_in(http, ["request", "method"]) end)
  end

  @doc """
  Extracts the URL string and then parses it to map using the URI module before passing it to diff.
  Note tha URI.parse returns a map so the order of the base URL is not accounted for when diffing.
  The query params are dealt with separately by diff_query_params/2
  """
  def diff_base_url(http1, http2) do
    diff_with_extraction(http1, http2, fn http ->
      %{scheme: scheme, host: host, path: path} = get_in(http, ["request", "url"]) |> URI.parse()
      %{"scheme" => scheme, "host" => host, "path" => path}
    end)
  end

  @doc """
  Extracts the URL string and then parses the query params to map using the URI module before
  passing it to diff. Note tha URI.parse returns a map so the order of the parameters is not
  accounted for when diffing.
  """
  def diff_query_params(http1, http2) do
    diff_with_extraction(http1, http2, fn http ->
      %{query: query} = get_in(http, ["request", "url"]) |> URI.parse()
      if query do
	URI.decode_query(query)
      else
	%{}
      end
    end)
  end
  
  @doc """
  Extracts the headers and transforms them into an ordered object before passing to diff/4 
  """
  def diff_headers(http1, http2, req_or_res) do
    diff_with_extraction(http1, http2, fn http ->
      http
      |> get_in([req_or_res, "headers"]) 
      |> Enum.map(fn header ->
	{header["name"], header["value"]}
      end)
      |> Jason.OrderedObject.new()
    end)
  end

   @doc """
   Extracts the bodies then
   - replaces nil with the "null" if necessary
   - decodes the body if it is json, otherwise will just leave it as  string
   - passes the results to diff
   """
  def diff_body(http1, http2, req_or_res) do
    diff_with_extraction(http1, http2, fn http ->
      http
      |> get_in([req_or_res, "body"])
      |> (fn body -> if body, do: body, else: "null" end).()
      |> (fn body ->
	case Jason.decode(body, objects: :ordered_objects) do
	  {:error, _} ->
	    body
	  {:ok, nil} ->
	    "null"
	  {:ok, decoded_body} ->
	    decoded_body
	end
      end).() 
    end)
  end

  def diff_status(http1, http2) do
    diff_with_extraction(http1, http2, fn http ->
      get_in(http, ["response", "status_code"])
    end)
  end

  ########################### IO for CLI tool #################################

  defimpl String.Chars, for: Jason.OrderedObject do
    def to_string(obj = %Jason.OrderedObject{}) do
      Jason.encode!(obj, pretty: true) 
    end
  end
  
  def decode_json_file(path) do
    case File.read(path) do
      {:error, reason} ->
	IO.puts("The following error occured when trying to read #{path}")
	IO.puts("Error: " <> List.to_string(:file.format_error(reason)))
	exit(:file_read_error)
      {:ok, contents} ->
	case Jason.decode(contents, objects: :ordered_objects) do 
	  {:error, _} ->
	    IO.puts("Could not decode the file #{path}")
	    exit(:file_decode_error)
	  {:ok, decoded_http_list} ->	    
	    decoded_http_list
	end
    end
  end

  def print_options(decoded_http_list) do
    decoded_http_list
    |> Enum.map(fn http ->
      method = get_in(http, ["request", "method"])
      %URI{scheme: scheme, host: host, path: path} = get_in(http, ["request", "url"]) |> URI.parse()
      method <> " " <> scheme <> "://" <> host <> path
    end)
    |> Enum.with_index()
    |> Enum.map(fn {url, idx} ->
      IO.puts("[#{idx}] #{url}")
    end)
    IO.puts("")
  end

  def get_selection(http_list, prompt) do
    input = IO.gets(prompt) |> String.trim()
    case Integer.parse(input) do
      :error ->
	IO.puts("Input must be an integer")
	get_selection(http_list, prompt)
      {int_input, _} ->
	case Enum.at(http_list, int_input, :invalid_selection) do
	  :invalid_selection ->
	    IO.puts("Not a valid selection")
	    get_selection(http_list, prompt)
	  http ->
	    http
	end
    end
  end

  @doc """
  Takes in a path (list of string keys) and formats them to a JS object access for printing
  eg. ["info", "age"] => "info.age:"
  """
  def format_path([]), do: ""
  def format_path([key | keys]) do
    Enum.reduce(keys, key, fn k, acc ->
      acc <> "." <> k
    end) <> ":"
  end

  def print_patch(%{type: :insert, path: path, new_value: new_value}) do
    IO.ANSI.format([:green, "+ #{format_path(path)} #{new_value}"]) |> IO.puts()
    IO.puts("")
  end

  def print_patch(%{type: :delete, path: path, old_value: old_value}) do
    IO.ANSI.format([:red, "- #{format_path(path)} #{old_value}"]) |> IO.puts()
    IO.puts("")
  end

  def print_patch(%{type: :update, path: path, new_value: new_value, old_value: old_value}) do
    IO.puts(format_path(path))
    IO.ANSI.format([:red, "- #{old_value}"]) |> IO.puts()    
    IO.ANSI.format([:green, "+ #{new_value}"]) |> IO.puts()
    IO.puts("")
  end

  def print_patch(%{type: :reorder, path: path, new_value: new_value, old_value: old_value}) do
    IO.ANSI.format([:red, "[#{old_value}]", :reset," -> ", :green, "[#{new_value}] ",:reset, "#{format_path(path)} ..." ])
    |> IO.puts()
    IO.puts("")
  end
  
  def print_patches(patches = %HttpDiff{}, section_header) do
    patches =  Map.from_struct(patches)
    unless Enum.all?(patches, fn {_, patch_set} -> Enum.empty?(patch_set) end) do
      IO.puts("----- #{section_header} -----")
       Enum.map(patches, fn {type, patch_list} ->
	unless Enum.empty?(patch_list) do
	  type
	  |> Atom.to_string()
	  |> String.upcase()
	  |> IO.puts()
	  Enum.map(patch_list, &print_patch/1)
	end
      end)
    end
  end
  
  def main_loop(http_list1, http_list2) do
    # Present options to user
    print_options(http_list1)
    print_options(http_list2)
    # Accept user selection
    http1 = get_selection(http_list1, "First Choice => ")
    http2 = get_selection(http_list2, "Second Choice => ")
    # Compute and display results
    diff_version(http1, http2) |> print_patches("HTTP VERSION")
    diff_method(http1, http2) |> print_patches("METHOD")
    diff_base_url(http1, http2) |> print_patches("BASE URL")
    diff_query_params(http1, http2) |> print_patches("QUERY PARAMETERS")
    diff_headers(http1, http2, "request") |> print_patches("REQUEST HEADERS")
    diff_body(http1, http2, "request") |> print_patches("REQUEST BODY")
    diff_status(http1, http2) |> print_patches("RESPONSE STATUS")
    diff_headers(http1, http2, "response") |> print_patches("RESPONSE HEADERS")
    diff_body(http1, http2, "response") |> print_patches("RESPONSE BODY")
    IO.puts("------  END ------")
    # Present options again
    main_loop(http_list1, http_list2)
    :ok
  end

  def main(argv) do
    case argv do
      [path1, path2] ->
        http_list1 = decode_json_file(path1)
	http_list2 = decode_json_file(path2)
	main_loop(http_list1, http_list2)
      _ ->
        IO.puts("Usage: <executable> <file1> <file2>")
    end
  end
  
end





