%{

#include "symbol_table.h"

#define YYSTYPE symbol_info*

extern FILE *yyin;
int yyparse(void);
int yylex(void);
extern YYSTYPE yylval;

// Create your symbol table here.
symbol_table *sym_table;

// Variables to store information during parsing for insertions
string current_type_specifier;
vector<pair<string, int>> declared_ids; 
vector<pair<string, string>> function_params; 
string function_return_type; 
string function_name; 
vector<symbol_info*> pending_parameter_symbols;
bool insert_params_next_scope = false;
unordered_set<string> current_param_names;
vector<string> current_call_arg_types;


int lines = 1;

ofstream outlog;
ofstream outerror;
int error_count = 0;
bool totals_written = false;

void report_error(const string &msg)
{
	outerror << "At line no: " << lines << " " << msg << endl << endl;
	error_count++;
}

void insert_pending_parameters_into_scope()
{
	if(!insert_params_next_scope)
	{
		return;
	}

	for(symbol_info *param_sym : pending_parameter_symbols)
	{
		sym_table->insert(param_sym);
	}

	pending_parameter_symbols.clear();
	insert_params_next_scope = false;
}

void yyerror(char *s)
{
    outerror<<"At line no: "<<lines<<" syntax error"<<endl<<endl;
    error_count++;
}

%}

%token IF ELSE FOR WHILE DO BREAK INT CHAR FLOAT DOUBLE VOID RETURN SWITCH CASE DEFAULT CONTINUE PRINTLN ADDOP MULOP INCOP DECOP RELOP ASSIGNOP LOGICOP NOT LPAREN RPAREN LCURL RCURL LTHIRD RTHIRD COMMA SEMICOLON CONST_INT CONST_FLOAT ID

%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE


%{
string normalizeType(const string &t){
	if(t=="int"||t=="INT") return "int";
	if(t=="float"||t=="FLOAT") return "float";
	if(t=="double"||t=="DOUBLE") return "double";
	if(t=="char"||t=="CHAR") return "char";
	if(t=="void"||t=="VOID") return "void";
	return t;
}
bool isIntegerType(const string &t){
	string n=normalizeType(t);
	return n=="int"||n=="char"; // treat char as integer-like
}
string mergeArithmeticType(const string &a,const string &b){
	string na=normalizeType(a), nb=normalizeType(b);
	if(na=="double"||nb=="double") return "double";
	if(na=="float"||nb=="float") return "float";
	if(isIntegerType(na)&&isIntegerType(nb)) return "int";
	return "void"; // unknown/invalid
}
string baseIdFromVarName(const string &name){
    size_t p=name.find('[');
    if(p==string::npos) return name;
    return name.substr(0,p);
}
%}

%%

start : program
	{
		outlog<<"At line no: "<<lines<<" start : program "<<endl<<endl;
		outlog<<"Symbol Table"<<endl<<endl;
		
		sym_table->print_all_scopes(outlog); // Print your whole symbol table here


	}
	;

program : program unit
	{
		outlog<<"At line no: "<<lines<<" program : program unit "<<endl<<endl;
		outlog<<$1->get_name()+"\n"+$2->get_name()<<endl<<endl;
		
		$$ = new symbol_info($1->get_name()+"\n"+$2->get_name(),"program");
	}
	| unit
	{
		outlog<<"At line no: "<<lines<<" program : unit "<<endl<<endl;
		outlog<<$1->get_name()<<endl<<endl;
		
		$$ = new symbol_info($1->get_name(),"program");
		
		if(!outerror.is_open()) outerror.open("22101047_error.txt");
	}
	;

unit : var_declaration
	 {
		outlog<<"At line no: "<<lines<<" unit : var_declaration "<<endl<<endl;
		outlog<<$1->get_name()<<endl<<endl;
		
		$$ = new symbol_info($1->get_name(),"unit");
	 }
     | func_definition
     {
		outlog<<"At line no: "<<lines<<" unit : func_definition "<<endl<<endl;
		outlog<<$1->get_name()<<endl<<endl;
		
		$$ = new symbol_info($1->get_name(),"unit");
	 }
     ;

func_decl_prefix : type_specifier ID
		{
			function_return_type = $1->get_name();
			function_name = $2->get_name();
			function_params.clear();
			pending_parameter_symbols.clear();
			current_param_names.clear();
			$$ = new symbol_info($1->get_name()+" "+$2->get_name(),"func_prefix");
		}
		;

func_definition : func_decl_prefix LPAREN parameter_list RPAREN
		{
			symbol_info *func_sym = new symbol_info(function_name, "ID", "function", function_return_type, function_params);
			bool ok = sym_table->insert(func_sym);
			if(!ok){
				report_error("Multiple declaration of function " + function_name);
			}
			insert_params_next_scope = !pending_parameter_symbols.empty();
		}
		compound_statement
		{ 
			outlog<<"At line no: "<<lines<<" func_definition : type_specifier ID LPAREN parameter_list RPAREN compound_statement "<<endl<<endl;
			outlog<<function_return_type<<" "<<function_name<<"("+$3->get_name()<<")\n"+$6->get_name()<<endl<<endl;
            
			function_name.clear();
			function_return_type.clear();
			function_params.clear();
			pending_parameter_symbols.clear();
			insert_params_next_scope = false;

			$$ = new symbol_info($1->get_name()+"("+$3->get_name()+")\n"+$6->get_name(),"func_def"); 
		}
		| func_decl_prefix LPAREN RPAREN
		{
			symbol_info *func_sym = new symbol_info(function_name, "ID", "function", function_return_type, function_params);
			bool ok = sym_table->insert(func_sym);
			if(!ok){
				report_error("Multiple declaration of function " + function_name);
			}
			insert_params_next_scope = false;
		}
		compound_statement
		{
			outlog<<"At line no: "<<lines<<" func_definition : type_specifier ID LPAREN RPAREN compound_statement "<<endl<<endl;
			outlog<<function_return_type<<" "<<function_name<<"()\n"+$4->get_name()<<endl<<endl;
            
			function_name.clear();
			function_return_type.clear();
			function_params.clear();
			pending_parameter_symbols.clear();
			insert_params_next_scope = false;

			$$ = new symbol_info($1->get_name()+"()\n"+$4->get_name(),"func_def"); 
		}
		;

parameter_list : parameter_list COMMA type_specifier ID
		{
			outlog<<"At line no: "<<lines<<" parameter_list : parameter_list COMMA type_specifier ID "<<endl<<endl;
			outlog<<$1->get_name()<<","<<$3->get_name()<<" "<<$4->get_name()<<endl<<endl;
					
           
			// check duplicate parameter names in same function
			string pname = $4->get_name();
			if(current_param_names.count(pname)){
				report_error("Multiple declaration of variable " + pname + " in parameter of " + function_name);
			}
			current_param_names.insert(pname);
			function_params.push_back({$3->get_name(), pname});
			symbol_info *param_sym = new symbol_info($4->get_name(), "ID", "variable", $3->get_name());
			pending_parameter_symbols.push_back(param_sym);

			$$ = new symbol_info($1->get_name()+","+$3->get_name()+" "+$4->get_name(),"param_list");
		}
		| parameter_list COMMA type_specifier
		{
			outlog<<"At line no: "<<lines<<" parameter_list : parameter_list COMMA type_specifier "<<endl<<endl;
			outlog<<$1->get_name()<<","<<$3->get_name()<<endl<<endl;
			
          
            function_params.push_back({$3->get_name(), ""}); 
         

			$$ = new symbol_info($1->get_name()+","+$3->get_name(),"param_list");
		}
 		| type_specifier ID
 		{
			outlog<<"At line no: "<<lines<<" parameter_list : type_specifier ID "<<endl<<endl;
			outlog<<$1->get_name()<<" "<<$2->get_name()<<endl<<endl;
			
           
			string pname = $2->get_name();
			if(current_param_names.count(pname)){
				report_error("Multiple declaration of variable " + pname + " in parameter of " + function_name);
			}
			current_param_names.insert(pname);
			function_params.push_back({$1->get_name(), pname});
            symbol_info *param_sym = new symbol_info($2->get_name(), "ID", "variable", $1->get_name());
            pending_parameter_symbols.push_back(param_sym);

			$$ = new symbol_info($1->get_name()+" "+$2->get_name(),"param_list");
		}
		| type_specifier
		{
			outlog<<"At line no: "<<lines<<" parameter_list : type_specifier "<<endl<<endl;
			outlog<<$1->get_name()<<endl<<endl;
			
            function_params.push_back({$1->get_name(), ""}); 
           

			$$ = new symbol_info($1->get_name(),"param_list");
		}
 		;

compound_statement : LCURL
            {
              
                sym_table->enter_scope();
				insert_pending_parameters_into_scope();
            }
            statements RCURL
			{ 
	 	    	outlog<<"At line no: "<<lines<<" compound_statement : LCURL statements RCURL "<<endl<<endl;
				outlog<<"{\n"+$3->get_name()+"\n}"<<endl<<endl;
				
				$$ = new symbol_info("{\n"+$3->get_name()+"\n}","comp_stmnt");
				
             
                sym_table->exit_scope();
 		    }
 		    | LCURL
            {
               
                sym_table->enter_scope();
				insert_pending_parameters_into_scope();
            }
            RCURL
 		    { 
 		    	outlog<<"At line no: "<<lines<<" compound_statement : LCURL RCURL "<<endl<<endl;
				outlog<<"{\n}"<<endl<<endl;
			$$ = new symbol_info("{\n}","comp_stmnt");
			outlog.flush();
			outerror.flush();
			sym_table->exit_scope();
		 }
 		 ;

type_specifier : INT
		{
			outlog<<"At line no: "<<lines<<" type_specifier : INT "<<endl<<endl;
			outlog<<"int"<<endl<<endl;
			
			$$ = new symbol_info("int","type");
			current_type_specifier = "int"; 
	    }
 		| FLOAT
 		{
			outlog<<"At line no: "<<lines<<" type_specifier : FLOAT "<<endl<<endl;
			outlog<<"float"<<endl<<endl;
			
			$$ = new symbol_info("float","type");
			current_type_specifier = "float";
	    }
 		| VOID
 		{
			outlog<<"At line no: "<<lines<<" type_specifier : VOID "<<endl<<endl;
			outlog<<"void"<<endl<<endl;
			
			$$ = new symbol_info("void","type");
			current_type_specifier = "void"; 
	    }
 		| CHAR 
        {
            outlog<<"At line no: "<<lines<<" type_specifier : CHAR "<<endl<<endl;
            outlog<<"char"<<endl<<endl;
            $$ = new symbol_info("char","type");
			current_type_specifier = "char";
        }
        | DOUBLE
        {
            outlog<<"At line no: "<<lines<<" type_specifier : DOUBLE "<<endl<<endl;
            outlog<<"double"<<endl<<endl;
            $$ = new symbol_info("double","type");
			current_type_specifier = "double";
        }
 		;

declaration_list : declaration_list COMMA ID
		  {
 		  	outlog<<"At line no: "<<lines<<" declaration_list : declaration_list COMMA ID "<<endl<<endl;
 		  	outlog<<$1->get_name()+","<<$3->get_name()<<endl<<endl;

            declared_ids.push_back({$3->get_name(), -1});
			$$ = new symbol_info($1->get_name()+","+$3->get_name(),"decl_list");
 		  }
 		  | declaration_list COMMA ID LTHIRD CONST_INT RTHIRD 
 		  {
 		  	outlog<<"At line no: "<<lines<<" declaration_list : declaration_list COMMA ID LTHIRD CONST_INT RTHIRD "<<endl<<endl;
 		  	outlog<<$1->get_name()+","<<$3->get_name()<<"["<<$5->get_name()<<"]"<<endl<<endl;

            declared_ids.push_back({$3->get_name(), stoi($5->get_name())});
			$$ = new symbol_info($1->get_name()+","+$3->get_name()+"["+$5->get_name()+"]","decl_list");
 		  }
  		| ID
  		  {
  		   	outlog<<"At line no: "<<lines<<" declaration_list : ID "<<endl<<endl;
			outlog<<$1->get_name()<<endl<<endl;

            declared_ids.push_back({$1->get_name(), -1});
			$$ = new symbol_info($1->get_name(),"decl_list");
  		  }
  		  | ID LTHIRD CONST_INT RTHIRD //array
 		  {
 		  	outlog<<"At line no: "<<lines<<" declaration_list : ID LTHIRD CONST_INT RTHIRD "<<endl<<endl;
			outlog<<$1->get_name()<<"["<<$3->get_name()<<"]"<<endl<<endl;

            declared_ids.push_back({$1->get_name(), stoi($3->get_name())});
            
			$$ = new symbol_info($1->get_name()+"["+$3->get_name()+"]","decl_list");
 		  }
 		  ;

var_declaration : type_specifier declaration_list SEMICOLON 
		  {
		  	outlog<<"At line no: "<<lines<<" var_declaration : type_specifier declaration_list SEMICOLON "<<endl<<endl;
			outlog<<$1->get_name()<<" "<<$2->get_name()<<";"<<endl<<endl;

			current_type_specifier = $1->get_name(); 

			for(const auto& decl : declared_ids) {
				string tnorm = normalizeType(current_type_specifier);
				if(tnorm=="void" && decl.second<0){
					report_error("variable type can not be void ");
				}
				symbol_info *var_sym;
				if (decl.second >= 0) {
					var_sym = new symbol_info(decl.first, "ID", "array", current_type_specifier, decl.second);
				} else {
					var_sym = new symbol_info(decl.first, "ID", "variable", current_type_specifier);
				}
				bool ok = sym_table->insert(var_sym);
				if(!ok){
					report_error("Multiple declaration of variable " + decl.first);
				}
			}
			declared_ids.clear(); 

			$$ = new symbol_info($1->get_name()+" "+$2->get_name()+";","var_dec");
		  }
		  ;
 		  

statements : statement
	   {
	    	outlog<<"At line no: "<<lines<<" statements : statement "<<endl<<endl;
			outlog<<$1->get_name()<<endl<<endl;
			
			$$ = new symbol_info($1->get_name(),"stmnts");
	   }
	   | statements statement
	   {
	    	outlog<<"At line no: "<<lines<<" statements : statements statement "<<endl<<endl;
			outlog<<$1->get_name()<<"\n"<<$2->get_name()<<endl<<endl;
			
			$$ = new symbol_info($1->get_name()+"\n"+$2->get_name(),"stmnts");
	   }
	   ;
	   
statement : var_declaration
	  {
	    	outlog<<"At line no: "<<lines<<" statement : var_declaration "<<endl<<endl;
			outlog<<$1->get_name()<<endl<<endl;
			
			$$ = new symbol_info($1->get_name(),"stmnt");
	  }
	  | expression_statement
	  {
	    	outlog<<"At line no: "<<lines<<" statement : expression_statement "<<endl<<endl;
			outlog<<$1->get_name()<<endl<<endl;
			
			$$ = new symbol_info($1->get_name(),"stmnt");
	  }
	  | compound_statement
	  {
	    	outlog<<"At line no: "<<lines<<" statement : compound_statement "<<endl<<endl;
			outlog<<$1->get_name()<<endl<<endl;
			
			$$ = new symbol_info($1->get_name(),"stmnt");
	  }
	  | FOR LPAREN expression_statement expression_statement expression RPAREN statement
	  {
	    	outlog<<"At line no: "<<lines<<" statement : FOR LPAREN expression_statement expression_statement expression RPAREN statement "<<endl<<endl;
			outlog<<"for("<<$3->get_name()<<$4->get_name()<<$5->get_name()<<")\n"<<$7->get_name()<<endl<<endl;
			
			$$ = new symbol_info("for("+$3->get_name()+$4->get_name()+$5->get_name()+")\n"+$7->get_name(),"stmnt");
	  }
	  | IF LPAREN expression RPAREN statement %prec LOWER_THAN_ELSE
	  {
	    	outlog<<"At line no: "<<lines<<" statement : IF LPAREN expression RPAREN statement "<<endl<<endl;
			outlog<<"if("<<$3->get_name()<<")\n"<<$5->get_name()<<endl<<endl;
			
			$$ = new symbol_info("if("+$3->get_name()+")\n"+$5->get_name(),"stmnt");
	  }
	  | IF LPAREN expression RPAREN statement ELSE statement
	  {
	    	outlog<<"At line no: "<<lines<<" statement : IF LPAREN expression RPAREN statement ELSE statement "<<endl<<endl;
			outlog<<"if("<<$3->get_name()<<")\n"<<$5->get_name()<<"\nelse\n"<<$7->get_name()<<endl<<endl;
			
			$$ = new symbol_info("if("+$3->get_name()+")\n"+$5->get_name()+"\nelse\n"+$7->get_name(),"stmnt");
	  }
	  | WHILE LPAREN expression RPAREN statement
	  {
	    	outlog<<"At line no: "<<lines<<" statement : WHILE LPAREN expression RPAREN statement "<<endl<<endl;
			outlog<<"while("<<$3->get_name()<<")\n"<<$5->get_name()<<endl<<endl;
			
			$$ = new symbol_info("while("+$3->get_name()+")\n"+$5->get_name(),"stmnt");
	  }
	  | PRINTLN LPAREN ID RPAREN SEMICOLON
	  {
	    	outlog<<"At line no: "<<lines<<" statement : PRINTLN LPAREN ID RPAREN SEMICOLON "<<endl<<endl;
			outlog<<"printf("<<$3->get_name()<<");"<<endl<<endl; 
			
				// Lookup ID in symbol table and report undeclared variable in error file
				symbol_info *looked_up_sym = sym_table->lookup($3);
				if(!looked_up_sym) {
					report_error("Undeclared variable " + $3->get_name());
				}

			$$ = new symbol_info("printf("+$3->get_name()+");","stmnt");
	  }
	  | RETURN expression SEMICOLON
	  {
	    	outlog<<"At line no: "<<lines<<" statement : RETURN expression SEMICOLON "<<endl<<endl;
			outlog<<"return "<<$2->get_name()<<";"<<endl<<endl;
			
			$$ = new symbol_info("return "+$2->get_name()+";","stmnt");
	  }
	  ;
	  
expression_statement : SEMICOLON
			{
				outlog<<"At line no: "<<lines<<" expression_statement : SEMICOLON "<<endl<<endl;
				outlog<<";"<<endl<<endl;
				
				$$ = new symbol_info(";","expr_stmt");
	        }			
			| expression SEMICOLON 
			{
				outlog<<"At line no: "<<lines<<" expression_statement : expression SEMICOLON "<<endl<<endl;
				outlog<<$1->get_name()<<";"<<endl<<endl;
				
				$$ = new symbol_info($1->get_name()+";","expr_stmt");
	        }
			;
	  
variable : ID 	
	  {
	outlog<<"At line no: "<<lines<<" variable : ID "<<endl<<endl;
	outlog<<$1->get_name()<<endl<<endl;
            
        
		symbol_info *looked_up_sym = sym_table->lookup($1);
		if(!looked_up_sym) {
			report_error("Undeclared variable " + $1->get_name());
		}

		// Using an array without index in expression: report and mark type void to avoid cascades
		if(looked_up_sym && looked_up_sym->get_kind()=="array"){
			report_error("variable is of array type : " + $1->get_name());
			$$ = new symbol_info($1->get_name(), "void");
		} else {
			$$ = new symbol_info($1->get_name(), normalizeType( looked_up_sym? (looked_up_sym->get_kind()=="function"? looked_up_sym->get_returnType(): looked_up_sym->get_dataType()) : "void"));
		}
        
	 }	
	 | ID LTHIRD expression RTHIRD 
	 	 {
	 	 	outlog<<"At line no: "<<lines<<" variable : ID LTHIRD expression RTHIRD "<<endl<<endl;
	 		outlog<<$1->get_name()<<"["<<$3->get_name()<<"]"<<endl<<endl;
 		
        
	 		symbol_info *looked_up_sym = sym_table->lookup($1);
	        bool err = false;
	 		if(!(looked_up_sym && looked_up_sym->get_kind() == "array")) {
	 			report_error("variable is not of array type : " + $1->get_name());
	            err = true;
	 		}
	 		// Array index must be integer
	 		if(!isIntegerType($3->get_type())){
	 			report_error("array index is not of integer type : " + $1->get_name());
	            err = true;
	 		}

	        if(err){
	            $$ = new symbol_info($1->get_name()+"["+$3->get_name()+"]", "void");
	        } else {
	 		    $$ = new symbol_info($1->get_name()+"["+$3->get_name()+"]", normalizeType( looked_up_sym? looked_up_sym->get_dataType(): "void"));
	        }
	 	 }
	 ;
	 
expression : logic_expression
	   {
	    	outlog<<"At line no: "<<lines<<" expression : logic_expression "<<endl<<endl;
			outlog<<$1->get_name()<<endl<<endl;
			
			$$ = new symbol_info($1->get_name(), $1->get_type());
	   }
	   | variable ASSIGNOP logic_expression 	
	   {
	    	outlog<<"At line no: "<<lines<<" expression : variable ASSIGNOP logic_expression "<<endl<<endl;
			outlog<<$1->get_name()<<"="<<$3->get_name()<<endl<<endl;

            
			symbol_info *looked_up_sym = sym_table->lookup(new symbol_info(baseIdFromVarName($1->get_name()),"ID"));
			if(looked_up_sym) {
				string lhsType = normalizeType(looked_up_sym->get_dataType());
				string rhsType = normalizeType($3->get_type());
				// If RHS is a void expression and it's not a composite arithmetic expression,
				// emit operation-on-void here to catch cases like: x = foo4(y);
				if(rhsType=="void"){
					string rs = $3->get_name();
					if(rs.find('+')==string::npos && rs.find('-')==string::npos && rs.find('*')==string::npos && rs.find('/')==string::npos && rs.find('%')==string::npos){
						report_error("operation on void type ");
					}
				}
				if(lhsType=="void") {
					report_error("Cannot assign to void-typed variable '" + $1->get_name() + "'");
				}
				// Array used without index on LHS: already reported by variable rule; avoid duplicate emission here
				// float/double to int assignment warning
				if(isIntegerType(lhsType) && (rhsType=="float" || rhsType=="double")) {
					report_error("Warning: Assignment of float value into variable of integer type ");
				}
			}

			$$ = new symbol_info($1->get_name()+"="+$3->get_name(), looked_up_sym? normalizeType(looked_up_sym->get_dataType()) : $3->get_type());
	   }
	   ;
			
logic_expression : rel_expression
	     {
	    	outlog<<"At line no: "<<lines<<" logic_expression : rel_expression "<<endl<<endl;
			outlog<<$1->get_name()<<endl<<endl;
			
			$$ = new symbol_info($1->get_name(), $1->get_type());
	     }	
		 | rel_expression LOGICOP rel_expression 
		 {
	    	outlog<<"At line no: "<<lines<<" logic_expression : rel_expression LOGICOP rel_expression "<<endl<<endl;
			outlog<<$1->get_name()<<$2->get_name()<<$3->get_name()<<endl<<endl;
			
			// Logical operator result should be integer
			$$ = new symbol_info($1->get_name()+$2->get_name()+$3->get_name(),"int");
	     }	
		 ;
			
rel_expression	: simple_expression
		{
	    	outlog<<"At line no: "<<lines<<" rel_expression : simple_expression "<<endl<<endl;
			outlog<<$1->get_name()<<endl<<endl;
			
			$$ = new symbol_info($1->get_name(), $1->get_type());
	    }
		| simple_expression RELOP simple_expression
		{
	    	outlog<<"At line no: "<<lines<<" rel_expression : simple_expression RELOP simple_expression "<<endl<<endl;
			outlog<<$1->get_name()<<$2->get_name()<<$3->get_name()<<endl<<endl;
			
			// Relational operator result should be integer
			$$ = new symbol_info($1->get_name()+$2->get_name()+$3->get_name(),"int");
	    }
		;
				
simple_expression : term
          {
	    	outlog<<"At line no: "<<lines<<" simple_expression : term "<<endl<<endl;
			outlog<<$1->get_name()<<endl<<endl;
			
			$$ = new symbol_info($1->get_name(), $1->get_type());
			
	      }
          | simple_expression ADDOP term 
          {
        	outlog<<"At line no: "<<lines<<" simple_expression : simple_expression ADDOP term "<<endl<<endl;
			outlog<<$1->get_name()<<$2->get_name()<<$3->get_name()<<endl<<endl;
			$$ = new symbol_info($1->get_name()+$2->get_name()+$3->get_name(), mergeArithmeticType($1->get_type(), $3->get_type()));
          }
		  ;
					
term :	unary_expression 
     {
	    	outlog<<"At line no: "<<lines<<" term : unary_expression "<<endl<<endl;
			outlog<<$1->get_name()<<endl<<endl;
			
			$$ = new symbol_info($1->get_name(), $1->get_type());
			
	 }
     |  term MULOP unary_expression
     {
	    	outlog<<"At line no: "<<lines<<" term : term MULOP unary_expression "<<endl<<endl;
			outlog<<$1->get_name()<<$2->get_name()<<$3->get_name()<<endl<<endl;
			// Modulus must have integer operands; division/modulus RHS not zero
			// Using void in arithmetic is invalid; report once at the operator level
			if(normalizeType($1->get_type())=="void" || normalizeType($3->get_type())=="void"){
				report_error("operation on void type ");
			}
			string op = $2->get_name();
			string resultType;
			if(op=="%"){
				bool badType = (!isIntegerType($1->get_type()) || !isIntegerType($3->get_type()));
				if(badType){
					report_error("Modulus operator on non integer type ");
				}
				if($3->get_name()=="0"||$3->get_name()=="0.0"){
					report_error("Modulus by 0 ");
				}
				resultType = badType ? string("void") : string("int");
			}
			else if(op=="/"){
				if($3->get_name()=="0"||$3->get_name()=="0.0"){
					report_error("Second operator of division should not be 0 ");
				}
				resultType = mergeArithmeticType($1->get_type(),$3->get_type());
			}
			else {
				resultType = mergeArithmeticType($1->get_type(),$3->get_type());
			}
			$$ = new symbol_info($1->get_name()+$2->get_name()+$3->get_name(), resultType);
			
	 }
     ;

unary_expression : ADDOP unary_expression  
		 {
	    	outlog<<"At line no: "<<lines<<" unary_expression : ADDOP unary_expression "<<endl<<endl;
			outlog<<$1->get_name()<<$2->get_name()<<endl<<endl;
			
			$$ = new symbol_info($1->get_name()+$2->get_name(), $2->get_type());
	     }
		 | NOT unary_expression 
		 {
	    	outlog<<"At line no: "<<lines<<" unary_expression : NOT unary_expression "<<endl<<endl;
			outlog<<"!"<<$2->get_name()<<endl<<endl;
			
			$$ = new symbol_info("!"+$2->get_name(),"int");
	     }
		 | factor 
		 {
	    	outlog<<"At line no: "<<lines<<" unary_expression : factor "<<endl<<endl;
			outlog<<$1->get_name()<<endl<<endl;
			
			$$ = new symbol_info($1->get_name(), $1->get_type());
	     }
		 ;
	
factor	: variable
    {
	    outlog<<"At line no: "<<lines<<" factor : variable "<<endl<<endl;
		outlog<<$1->get_name()<<endl<<endl;
			
		$$ = new symbol_info($1->get_name(), $1->get_type());
	}
	| ID LPAREN { current_call_arg_types.clear(); } argument_list RPAREN
	{
	    outlog<<"At line no: "<<lines<<" factor : ID LPAREN argument_list RPAREN "<<endl<<endl;
		outlog<<$1->get_name()<<"("<<$4->get_name()<<")"<<endl<<endl;

       
		symbol_info *looked_up_sym = sym_table->lookup($1);
		if(!(looked_up_sym && looked_up_sym->get_kind() == "function")) {
			report_error("Undeclared function: " + $1->get_name());
		} else {
			// Check parameter count
			const auto &params = looked_up_sym->get_parameters();
			if(params.size() != current_call_arg_types.size()){
				report_error(string("Inconsistencies in number of arguments in function call: ") + looked_up_sym->get_name());
			}
			// Type checks for available pairs
			size_t common = min(params.size(), current_call_arg_types.size());
			for(size_t i=0;i<common;++i){
				string p = normalizeType(params[i].first);
				string a = normalizeType(current_call_arg_types[i]);
				if(a=="void") continue; // skip cascaded errors from invalid args
				bool ok = false;
				if(p==a) ok=true;
				else if(isIntegerType(p) && isIntegerType(a)) ok=true; // int/char compatibility
				// else allow implicit int->float/double? keep strict to match samples
				if(!ok){
					report_error("argument " + to_string((int)i+1) + " type mismatch in function call: " + looked_up_sym->get_name());
				}
			}
			string ret = normalizeType(looked_up_sym->get_returnType());
			$$ = new symbol_info($1->get_name()+"("+$4->get_name()+")", ret);
            goto factor_done;
        }

		$$ = new symbol_info($1->get_name()+"("+$4->get_name()+")","void_undecl");
factor_done: ;
	}
	| LPAREN expression RPAREN
	{
	   	outlog<<"At line no: "<<lines<<" factor : LPAREN expression RPAREN "<<endl<<endl;
		outlog<<"("<<$2->get_name()<<")"<<endl<<endl;
		
		$$ = new symbol_info("("+$2->get_name()+")", $2->get_type());
	}
	| CONST_INT 
	{
	    outlog<<"At line no: "<<lines<<" factor : CONST_INT "<<endl<<endl;
		outlog<<$1->get_name()<<endl<<endl;
			
		$$ = new symbol_info($1->get_name(),"int");
	}
	| CONST_FLOAT
	{
	    outlog<<"At line no: "<<lines<<" factor : CONST_FLOAT "<<endl<<endl;
		outlog<<$1->get_name()<<endl<<endl;
			
		$$ = new symbol_info($1->get_name(),"float");
	}
	| variable INCOP 
	{
	    outlog<<"At line no: "<<lines<<" factor : variable INCOP "<<endl<<endl;
		outlog<<$1->get_name()<<"++"<<endl<<endl;
			
		$$ = new symbol_info($1->get_name()+"++", $1->get_type());
	}
	| variable DECOP
	{
	    outlog<<"At line no: "<<lines<<" factor : variable DECOP "<<endl<<endl;
		outlog<<$1->get_name()<<"--"<<endl<<endl;
			
		$$ = new symbol_info($1->get_name()+"--", $1->get_type());
	}
	;
	
argument_list : arguments
			  {
					outlog<<"At line no: "<<lines<<" argument_list : arguments "<<endl<<endl;
					outlog<<$1->get_name()<<endl<<endl;
						
					$$ = new symbol_info($1->get_name(),"arg_list");
			  }
			  | /* empty */
			  {
					outlog<<"At line no: "<<lines<<" argument_list :  "<<endl<<endl;
					outlog<<""<<endl<<endl;
						
					$$ = new symbol_info("","arg_list");
			  }
			  ;
	
arguments : arguments COMMA logic_expression
		  {
				outlog<<"At line no: "<<lines<<" arguments : arguments COMMA logic_expression "<<endl<<endl;
				outlog<<$1->get_name()<<","<<$3->get_name()<<endl<<endl;
				// collect argument type
				current_call_arg_types.push_back(normalizeType($3->get_type()));
				$$ = new symbol_info($1->get_name()+","+$3->get_name(),"arg");
		  }
	      | logic_expression
	      {
				outlog<<"At line no: "<<lines<<" arguments : logic_expression "<<endl<<endl;
				outlog<<$1->get_name()<<endl<<endl;
				// collect argument type
				current_call_arg_types.push_back(normalizeType($1->get_type()));
				$$ = new symbol_info($1->get_name(),"arg");
		  }
	      ;


%%

int main(int argc,char *argv[])
{
    outlog.open("22101047_log.txt", ios::trunc);
    outerror.open("22101047_error.txt", ios::trunc);

    const char* path = (argc>=2) ? argv[1] : "input.c";
    yyin = fopen(path,"r");
    if(!yyin){
        if(outlog.is_open()) outlog<<"Couldn't open file"<<endl;
        // Write totals even on failure
        if(!totals_written){
            if(outlog.is_open()){
                outlog<<endl<<"Total lines: "<<lines<<endl;
                outlog<<"Total errors: "<<error_count<<endl;
            }
            if(outerror.is_open()){
                outerror<<endl<<"Total errors: "<<error_count<<endl;
            }
            totals_written = true;
        }
        if(outlog.is_open()) outlog.close();
        if(outerror.is_open()) outerror.close();
        return 0;
    }

    sym_table = new symbol_table(10);

    yyparse();

    // Write totals exactly once here
    if(!totals_written){
        if(outlog.is_open()){
            outlog<<endl<<"Total lines: "<<lines<<endl;
            outlog<<"Total errors: "<<error_count<<endl;
        }
        if(outerror.is_open()){
            outerror<<endl<<"Total errors: "<<error_count<<endl;
        }
        totals_written = true;
    }

    if(yyin) fclose(yyin);
    if(outlog.is_open()) outlog.close();
    if(outerror.is_open()) outerror.close();
    delete sym_table;
    return 0;
}
