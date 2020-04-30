include (ResourceCompiler)
add_resource_object (resource 
	file.txt)

add_executable (test_resource_compiler main.cxx)

target_link_libraries (test_resource_compiler PRIVATE resource)
