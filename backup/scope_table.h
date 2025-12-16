#include "symbol_info.h"

class scope_table
{
private:
    int bucket_count;
    int unique_id;
    scope_table *parent_scope = NULL;
    vector<list<symbol_info *>> table;
    friend class symbol_table;

    int hash_function(string name)
    {
        long long sum = 0;
        for (char c : name)
        {
            sum += c;
        }
        return bucket_count ? (sum % bucket_count) : 0;
    }

public:
    scope_table() : bucket_count(0), unique_id(0), parent_scope(NULL) {}

    scope_table(int bucket_count, int unique_id, scope_table *parent_scope)
    {
        this->bucket_count = bucket_count;
        this->unique_id = unique_id;
        this->parent_scope = parent_scope;
        table.resize(bucket_count);
    }

    scope_table *get_parent_scope()
    {
        return parent_scope;
    }

    int get_unique_id()
    {
        return unique_id;
    }

    symbol_info *lookup_in_scope(symbol_info *symbol)
    {
        int hash_value = hash_function(symbol->get_name());
        for (symbol_info *s : table[hash_value])
        {
            if (s->get_name() == symbol->get_name())
            {
                return s;
            }
        }
        return NULL;
    }

    bool insert_in_scope(symbol_info *symbol)
    {
        if (lookup_in_scope(symbol) != NULL)
        {
            return false;
        }

        int hash_value = hash_function(symbol->get_name());
        table[hash_value].push_back(symbol);
        return true;
    }

    bool delete_from_scope(symbol_info *symbol)
    {
        int hash_value = hash_function(symbol->get_name());
        auto &bucket = table[hash_value];
        for (auto it = bucket.begin(); it != bucket.end(); ++it)
        {
            if ((*it)->get_name() == symbol->get_name())
            {
                delete *it;
                bucket.erase(it);
                return true;
            }
        }
        return false;
    }

    void print_scope_table(ofstream &outlog)
    {
        bool printed_any_bucket = false;
        for (int i = 0; i < bucket_count; ++i)
        {
            if (table[i].empty())
            {
                continue;
            }

            if (!printed_any_bucket)
            {
                outlog << "ScopeTable # " << unique_id << endl;
                printed_any_bucket = true;
            }

            outlog << i << " --> " << endl;

            for (symbol_info *s : table[i])
            {
                outlog << "< " << s->get_name() << " : " << s->get_type() << " >" << endl;

                if (s->get_kind() == "variable")
                {
                    outlog << "Variable" << endl;
                    outlog << "Type: " << s->get_dataType() << endl;
                }
                else if (s->get_kind() == "array")
                {
                    outlog << "Array" << endl;
                    outlog << "Type: " << s->get_dataType() << endl;
                    outlog << "Size: " << s->get_arraySize() << endl;
                }
                else if (s->get_kind() == "function")
                {
                    outlog << "Function Definition" << endl;
                    outlog << "Return Type: " << s->get_returnType() << endl;
                    const auto &params = s->get_parameters();
                    outlog << "Number of Parameters: " << params.size() << endl;
                    outlog << "Parameter Details: ";
                    if (params.empty())
                    {
                        outlog << endl;
                    }
                    else
                    {
                        for (size_t idx = 0; idx < params.size(); ++idx)
                        {
                            const auto &param = params[idx];
                            outlog << param.first;
                            if (!param.second.empty())
                            {
                                outlog << " " << param.second;
                            }
                            if (idx + 1 < params.size())
                            {
                                outlog << ", ";
                            }
                        }
                        outlog << endl;
                    }
                }

                outlog << endl;
            }
        }

        if (printed_any_bucket)
        {
            outlog << endl;
        }
    }

    ~scope_table()
    {
        for (int i = 0; i < bucket_count; ++i)
        {
            for (symbol_info *s : table[i])
            {
                delete s;
            }
            table[i].clear();
        }
    }
};