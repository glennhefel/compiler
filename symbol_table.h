#include "scope_table.h"

extern ofstream outlog;

class symbol_table
{
private:
    scope_table *current_scope;
    int bucket_count;
    int current_scope_id;

public:
    symbol_table(int bucket_count)
    {
        this->bucket_count = bucket_count;
        current_scope = NULL;
        current_scope_id = 0;
        enter_scope();
    }

    ~symbol_table()
    {
        while (current_scope != NULL)
        {
            scope_table *temp = current_scope;
            current_scope = current_scope->get_parent_scope();
            delete temp;
        }
    }

    void enter_scope()
    {
        current_scope_id++;
        scope_table *new_scope = new scope_table(bucket_count, current_scope_id, current_scope);
        current_scope = new_scope;
        outlog << "New ScopeTable with ID " << current_scope_id << " created" << endl
               << endl;
    }

    void exit_scope()
    {
        if (current_scope == NULL)
        {
            outlog << "No scope to exit." << endl;
            return;
        }

        print_all_scopes(outlog);
        outlog << "Scopetable with ID " << current_scope->get_unique_id() << " removed" << endl
               << endl;
        
        outlog.flush(); // Flush immediately

        scope_table *temp = current_scope;
        current_scope = current_scope->get_parent_scope();
        delete temp;
    }

    bool insert(symbol_info *symbol)
    {
        if (current_scope == NULL)
        {
            outlog << "Error: No current scope to insert into." << endl;
            return false;
        }
        bool success = current_scope->insert_in_scope(symbol);
        if (!success)
        {
            outlog << "Error: " << symbol->get_name()
                   << " already exists in the current ScopeTable" << endl;
        }
        return success;
    }

    symbol_info *lookup(symbol_info *symbol)
    {
        scope_table *temp_scope = current_scope;
        while (temp_scope != NULL)
        {
            symbol_info *found_symbol = temp_scope->lookup_in_scope(symbol);
            if (found_symbol != NULL)
            {
                return found_symbol;
            }
            temp_scope = temp_scope->get_parent_scope();
        }
        return NULL;
    }

    bool remove(symbol_info *symbol)
    {
        if (current_scope == NULL)
        {
            outlog << "Error: No current scope to delete from." << endl;
            return false;
        }
        bool success = current_scope->delete_from_scope(symbol);
        if (success)
        {
            outlog << "Deleted from ScopeTable # " << current_scope->get_unique_id() << endl;
        }
        else
        {
            outlog << "Error: " << symbol->get_name()
                   << " not found in the current ScopeTable for deletion." << endl;
        }
        return success;
    }

    void print_current_scope()
    {
        if (current_scope != NULL)
        {
            current_scope->print_scope_table(outlog);
        }
        else
        {
            outlog << "No current scope to print." << endl;
        }
    }

    void print_all_scopes(ofstream &out)
    {
        out << "################################" << endl
            << endl;
        scope_table *temp = current_scope;
        while (temp != NULL)
        {
            temp->print_scope_table(out);
            temp = temp->get_parent_scope();
        }
        out << "################################" << endl
            << endl;
    }
};