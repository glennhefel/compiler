#include<bits/stdc++.h>
using namespace std;

class symbol_info
{
private:
    string name;
    string type; // Token type  ID, INT, FLOAT, ADDOP etc

    // Attributes needed by the symbol table
    string kind; // "variable", "array", "function"
    string dataType; // Data type for variables / parameter type for arrays
    int arraySize = 0; 
    vector<pair<string, string>> parameters; // Function parameters: <dataType, paramName>
    string returnType; 

public:
    symbol_info(string name, string type)
    {
        this->name = name;
        this->type = type;
    }

    symbol_info(string name, string type, string kind, string dataType)
    {
        this->name = name;
        this->type = type;
        this->kind = kind;
        this->dataType = dataType;
    }

    symbol_info(string name, string type, string kind, string dataType, int arraySize)
    {
        this->name = name;
        this->type = type;
        this->kind = kind;
        this->dataType = dataType;
        this->arraySize = arraySize;
    }

    symbol_info(string name, string type, string kind, string returnType,
                const vector<pair<string, string>>& params)
    {
        this->name = name;
        this->type = type;
        this->kind = kind;
        this->returnType = returnType;
        this->parameters = params;
    }

    string get_name() const
    {
        return name;
    }

    string get_type() const
    {
        return type;
    }

    void set_name(string name)
    {
        this->name = name;
    }

    void set_type(string type)
    {
        this->type = type;
    }

    string get_kind() const
    {
        return kind;
    }

    void set_kind(string kind)
    {
        this->kind = kind;
    }

    string get_dataType() const
    {
        return dataType;
    }

    void set_dataType(string dataType)
    {
        this->dataType = dataType;
    }

    int get_arraySize() const
    {
        return arraySize;
    }

    void set_arraySize(int size)
    {
        arraySize = size;
    }

    const vector<pair<string, string>>& get_parameters() const
    {
        return parameters;
    }

    void set_parameters(const vector<pair<string, string>>& params)
    {
        parameters = params;
    }

    string get_returnType() const
    {
        return returnType;
    }

    void set_returnType(string rType)
    {
        returnType = rType;
    }
};