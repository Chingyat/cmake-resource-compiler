set(RC_COMPILE_SCRIPT "${CMAKE_CURRENT_LIST_FILE}")

function(add_resource_object name)
  cmake_parse_arguments(ARG "STATIC;SHARED;OBJECT;"
                        "NAMESPACE;HEADER_FILE;ASM_FILE" ";" ${ARGN})

  set(rc_asm_file "${CMAKE_CURRENT_BINARY_DIR}/${name}.rc.S")
  set(rc_header_file "${CMAKE_CURRENT_BINARY_DIR}/${name}.hxx")
  # set(rc_source_file "${CMAKE_CURRENT_BINARY_DIR}/${name}.cxx")

  if(ARG_NAMESPACE)
    set(rc_namespace "${ARG_NAMESPACE}")
  else()
    string(MAKE_C_IDENTIFIER "${name}" rc_namespace)
  endif()

  if(ARG_HEADER_FILE)
    set(rc_header_file "${ARG_HEADER_FILE}")
  endif()

  if(ARG_ASM_FILE)
    set(rc_asm_file "${ARG_ASM_FILE}")
  endif()

  set(rc_source_list "")
  foreach(source_file ${ARG_UNPARSED_ARGUMENTS})
    list(APPEND rc_source_list "${CMAKE_CURRENT_SOURCE_DIR}/${source_file}")
  endforeach(source_file)

  add_custom_command(
    OUTPUT "${rc_asm_file}" "${rc_header_file}"
    COMMAND
      "${CMAKE_COMMAND}" ARGS -DRC_ASM_FILE="\"${rc_asm_file}\"" -DTEST_ARG='a;b;c'
      -DRC_HEADER_FILE="\"${rc_header_file}\""
      -DRC_SOURCE_LIST="\"${rc_source_list}\"" -DRC_NAMESPACE="'${rc_namespace}'"
      -DRC_SOURCE_DIR="'${CMAKE_CURRENT_SOURCE_DIR}'" -P "'${RC_COMPILE_SCRIPT}'"
    DEPENDS ${rc_source_list} ${RC_COMPILE_SCRIPT})

  add_library(${name} OBJECT "${rc_asm_file}" "${rc_header_file}")

  target_include_directories(${name} INTERFACE ${CMAKE_CURRENT_BINARY_DIR})
  target_compile_features(${name} INTERFACE cxx_std_17)
endfunction()

if(RC_ASM_FILE)
  set(class_definition
      "#pragma once
#include <cstddef>
#include <iostream>
#include <string>
#include <memory>

namespace ${RC_NAMESPACE} {
    class embedded_object {
        const std::byte *start_, *end_;

    public:
        constexpr embedded_object(const std::byte *start, const std::byte *end)
            : start_(start), end_(end)
        {}

        constexpr embedded_object(const std::byte *start, std::uintptr_t size)
            : start_(start), end_(start + size)
        {}

        // explicit embedded_object(const std::string &symbol)
        // {
        //     void *handle = ::dlopen(nullptr, RTLD_NOW | RTLD_NOLOAD);
        //     assert(handle);
        //
        //     start_ = ::dlsym(handle, symbol.c_str());
        //     assert(start_);
        //     end_ = ::dlsym(handle, (symbol + \".end\").c_str());
        //     assert(end_);
        // }

        const std::byte *begin() const { return start_; }
        const std::byte *end() const { return end_; }
        const std::uintptr_t size() const { return end_ - start_; }

        std::string_view to_string_view() const { return std::string_view(reinterpret_cast<const char *>(begin()), size()); }
        std::string to_string() const { return std::string(to_string_view()); }
    };

    class embedded_file_buf : public std::streambuf {
    public:
        explicit embedded_file_buf(embedded_object obj)
        {
            char *start_pos = reinterpret_cast<char *>(const_cast<std::byte *>(obj.begin()));
            char *end_pos = reinterpret_cast<char *>(const_cast<std::byte *>(obj.end()));
            setg(start_pos, start_pos, end_pos);
        }

        // explicit embedded_file_buf(const std::string &symbol)
        //     : embedded_file_buf(embedded_object(symbol))
        // {
        //
        // }
    };

    class embedded_ifstream : public std::istream
    {
        std::unique_ptr<embedded_file_buf> file_buf_;
    public:
        explicit embedded_ifstream(embedded_object obj)
        {
            open(obj);
        }

        embedded_ifstream() = default;

        void open(embedded_object obj)
        {
            file_buf_ = std::make_unique<embedded_file_buf>(obj);
            rdbuf(file_buf_.get());
        }

        bool is_open() const
        {
	        return !!rdbuf();
        }

        void close()
        {
            file_buf_ = nullptr;
        }
    };
}

")

  set(addresses "")

  set(objects "")

  set(asm_content "")

  set(list ${RC_SOURCE_LIST})
  foreach(source ${list})
    file(RELATIVE_PATH relpath "${RC_SOURCE_DIR}" "${source}")
    string(MAKE_C_IDENTIFIER "${relpath}" identifier)
    set(asm_symbol "${RC_NAMESPACE}.${identifier}")

    string(
      APPEND
      addresses
      "extern const std::byte ${identifier}[] asm(\"${asm_symbol}\");
extern const std::byte ${identifier}_end[] asm(\"${asm_symbol}.end\");
extern const std::uintptr_t ${identifier}_size asm(\"${asm_symbol}.size\");
")

    string(
      APPEND
      objects
      "inline const embedded_object ${identifier}{ addresses::${identifier}, addresses::${identifier}_end };
")

    string(
      APPEND
      asm_contents
      "    .section .rodata
    .global ${asm_symbol}
    .global ${asm_symbol}.size
    .global ${asm_symbol}.end
    .align 4
${asm_symbol}:
    .incbin \"${source}\"
${asm_symbol}.end:
    .align 8
${asm_symbol}.size:
    .long  ${asm_symbol}.end - ${asm_symbol}
")

  endforeach(source)

  set(resource_declaration
      "namespace ${RC_NAMESPACE} { namespace addresses {
${addresses}
} }

namespace ${RC_NAMESPACE} {
${objects}
}
")

  file(WRITE "${RC_HEADER_FILE}" "${class_definition}${resource_declaration}")

  file(WRITE "${RC_ASM_FILE}" "${asm_contents}")

endif()
