#include <cassert>
#include <string>
#include "resource.hxx"

int main()
{
    resource::embedded_ifstream stream(resource::file_txt);

    std::string str;
    std::getline(stream, str);

    assert (str == "Hello world");
}


