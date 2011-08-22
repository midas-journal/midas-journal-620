/*=========================================================================

  Program:   Visualization Toolkit
  Module:    $RCSfile: vtkXML.c,v $

  Copyright (c) Ken Martin, Will Schroeder, Bill Lorensen
  All rights reserved.
  See Copyright.txt or http://www.kitware.com/Copyright.htm for details.

     This software is distributed WITHOUT ANY WARRANTY; without even
     the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
     PURPOSE.  See the above copyright notice for more information.

=========================================================================*/

/* Modified code from vtkWrapPython.c to make new parser vtkXML.c */


#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include "vtkParse.h"
#include "vtkConfigure.h"

/*
 The parser identifies VTK types with 16-bit hexidecimal numbers
*/

/*
 The lowest digit is the basic type,
 where 0x8 is used for unrecognized types
 and 0x9 can be used for any VTK object.

 0x1 = float
 0x2 = void
 0x3 = char
 0x4 = int
 0x5 = short
 0x6 = long
 0x7 = double
 0x8 = unrecognized type
 0x9 = vtk object
 0xA = vtkIdType
 0xB = long long
 0xC = __int64
 0xD = signed char
 0xE = bool
*/

/*
 The next digit is used to specify whether the
 type is "unsigned"

 0x10 = unsigned
*/

/*
 Pointers, arrays, and references
 (note that [] and * are equivalent)

 0x100 = &
 0x200 = &&
 0x300 = * or [n]
 0x400 = &*
 0x500 = *&
 0x600 = [n][m]
 0x700 = **
 0x900 = [n][m][l]
*/

/*
 Decorators: static and const, plus the special "function pointer"

 0x1000 = static
 0x2000 = const
 0x3000 = static const
 0x5000 = void (*func)(void *) i.e. a function pointer
*/

/* vtkXML will print this if any unsupported types or
   methods are encountered */
#define VTKXML_UNSUPPORTED "UNSUPPORTED"


/* used to store max size of array of expected number of get/set/add/remove functions */
#define MAX_ARRAY_SIZE 100


// next few functions are there to have final list in order
int compare(FileInfo *data, int first, int second)
	{
	return strcmp(data->Functions[first].Name,data->Functions[second].Name);
	}

void mySwap(int arr[], int first, int second)
	{
	int temp = arr[first];
	arr[first] = arr[second];
	arr[second] = temp;
	}

void sort(FileInfo *data, int functionList[], int start, int ends)
	{
	int i, location = start;
	if (ends <= start)
		{
		return;
		}
	for (i = start; i < ends; i++)
		{
		if (compare(data, functionList[ends], functionList[i]) > 0)
			{
			mySwap(functionList, location, i);
			location++;
			}
		}
	mySwap(functionList, location, ends);
	sort(data, functionList, start, location - 1);
	sort(data, functionList, location + 1, ends);
	}

// Used to have proper indentation in the XML file
void indent(FILE *fp, int indentation)
	{
	while (indentation > 0)
		{
		fprintf(fp, "\t");
		indentation--;
		}
	}

void separateFunctions(FILE *fp, FileInfo *data, int addFunctions[], int *endOfAddFunctions, int removeFunctions[], int *endOfRemoveFunctions, int setFunctions[], int *endOfSetFunctions, int getFunctions[], int *endOfGetFunctions)
	{
	int i =0 , j = 0, types = -1, check = 0;
  /* goes through all the functions in the data list and puts them into the proper array
  based on the function name so can later be compared to extract only the wanted parameter
  and input types.*/
	for (i = 0; i < data->NumberOfFunctions; i++)
		{
		check = 0;
		if ((!data->Functions[i].IsOperator &&   /* no operators */
		!data->Functions[i].ArrayFailure && /* no bad arrays */
		data->Functions[i].IsPublic &&    /* only public methods */
		data->Functions[i].Name) &&         /* only methods with parseable names */
		(data->Functions[i].ReturnType & 0xF000) != 0x2000 &&  /*only non-static methods */
		data->Functions[i].HintSize != -1)   /* make sure not an exception */
			{
			if (strncmp(data->Functions[i].Name, "Add", 3) == 0)  //Getting all functions that start with Add
				{
				(*endOfAddFunctions)++;
				addFunctions[*endOfAddFunctions] = i;
				}
			else if (strncmp(data->Functions[i].Name, "Remove", 6) == 0) //Getting all functions that start with Remove
				{
				(*endOfRemoveFunctions)++;
				removeFunctions[*endOfRemoveFunctions] = i;
				}
			else if (strncmp(data->Functions[i].Name, "Set", 3) == 0) //Getting all functions that start with Set
				{
				/*Add in a check to make sure that the function takes arguments all of the same type (as ones that take 
					different types are usually shortcuts for multiple functions (ex. StreamTracer with IntegrationSteps) */
				for (j = 0; j < data->Functions[i].NumberOfArguments; j++)
					{
					if (j == 0) //first item in list
						{
						types = data->Functions[i].ArgTypes[j];
						}
					else if ((types & 0xF) != 0x9)
						{
						if (types != data->Functions[i].ArgTypes[j]) //if the next argument does not match the previous types
							{
							check = 1;
							}
						}
					}
				if (check == 0)
					{
					(*endOfSetFunctions)++;
					setFunctions[*endOfSetFunctions] = i;
					}
				}
			else if (strncmp(data->Functions[i].Name, "Get", 3) == 0) //Getting all functions that start with Get
				{
				(*endOfGetFunctions)++;
				getFunctions[*endOfGetFunctions] = i;
				}
			}
   } //end for loop
}

/* put into second array only those functions that have the same ending Name in both lists (ignoring amounts specified in 
word1Lengths and word2Lengths part). 
Parameters are data = FileInfo created from parser
 firstFunctions = list of indices to check in data->Functions
 endOfFirstFunctions = pointer to int of the last currently used index in firstFunctions
 word1Length = length at start of function Name 1 to ignore*/
void checkMatchBetweenFirstAndSecondList(FILE *fp, FileInfo *data, int firstFunctions[], int *endOfFirstFunctions, int word1Length, int secondFunctions[], int *endOfSecondFunctions, int word2Length )
	{
	int i, j, k, alreadyIn, lastUsedIndex = -1;
  /* lastUsedIndex is to know where the next usable function should be placed. */
	//loop through all of second functions
  for (i = 0; i <= *endOfSecondFunctions; i++)
    {
		alreadyIn = -1;
		for (j = 0; j <= *endOfFirstFunctions; j++)
		  {
			/*want to make sure that the ends of the function names are the same, and that if it is a get function it takes no arguments (to 
			bypass RGBA/Z buffer, complex functions that are to be ignored.  Word1Length != word2Length is because both add and 
			remove take 1 argument always so no way have one as zero, so easy check to make sure not comparing add/remove is just
			checking the lengths.  NOT VERY ROBUST THOUGH! */
			if ( strcmp(data->Functions[secondFunctions[i]].Name + word2Length, data->Functions[firstFunctions[j]].Name + word1Length) == 0 && 
				((data->Functions[firstFunctions[j]].NumberOfArguments == 0) || word1Length != word2Length))
				{
				/* make sure it is not in the list already */
				for (k = 0; k <=lastUsedIndex; k++)
					{
					if (strcmp(data->Functions[secondFunctions[k]].Name, data->Functions[secondFunctions[i]].Name) == 0)
						{
						alreadyIn = i;
						break;
						}
					}
				if (alreadyIn == -1)
					{
					lastUsedIndex++;
					secondFunctions[lastUsedIndex] = secondFunctions[i];
					break;
					}
				}
		  }
	  }
	/* array likely shrunk due to removing unnecessary stuff so change endOfGetFunctions to new proper
	value */
	*endOfSecondFunctions = lastUsedIndex;		
}
/*Function that checks for all Get functions that returned an object type and had no matching set function.  These were all
promoted to be Outputs.  Leaves only the promoted function indices in the getFunctions list.*/
void getPromotedOutputs(FILE *fp, FileInfo *data, int getFunctions[], int *endOfGetFunctions, int setFunctions[], int *endOfSetFunctions)
	{
	int i, j, k, found, alreadyIn, lastUsedIndex = -1;
	for (i = 0; i <= *endOfGetFunctions; i++)
		{
		found = 0; /* to check if there was a corresponding set function*/
		alreadyIn = -1; /* so only put each get function in once */
		if ((data->Functions[getFunctions[i]].ReturnType & 0xF) == 0x9 /* returns a type*/
			&& (strstr(data->Functions[getFunctions[i]].Name, "Input") == NULL) /* not actually an input of some sort */
			&& (data->Functions[getFunctions[i]].NumberOfArguments == 0) ) /* takes no arguments */
			{
			/* goes through list of sorted set functions that have been matched to a get function already.  If get name not found by time it
			reaches position it should be alphabetically in set list, then the get Function is promoted to an output. */
			for (j = 0; j <= *endOfSetFunctions && strcmp(data->Functions[getFunctions[i]].Name + 3, data->Functions[setFunctions[j]].Name + 3) >= 0; j++)
				{
					if (strcmp(data->Functions[getFunctions[i]].Name + 3, data->Functions[setFunctions[j]].Name + 3) == 0 && strcmp(data->Functions[getFunctions[i]].Name, "GetOutput") != 0)
					{
					found = 1;
					break;
					}
				}
				for (k = 0; k <= lastUsedIndex; k++)
					{
					if (strcmp(data->Functions[getFunctions[k]].Name, data->Functions[getFunctions[i]].Name) == 0)
						{
						alreadyIn = i;
						break;
						}
					}
			if(found == 0 && alreadyIn == -1)
				{
				lastUsedIndex++;
				getFunctions[lastUsedIndex] = getFunctions[i];
				}
			}
		}
	/* array likely shrunk due to removal of those that were not promoted */
	*endOfGetFunctions = lastUsedIndex;
	}
/* check to make sure that only print right stuff as input. Returns 1 when was a set function that had been promoted
to input. Returns 0 otherwise. */
int InputFunctions(FILE *fp, FunctionInfo *func, int indentation)
	{
	int i = 0, type_number, value = 0; 
	if (func->NumberOfArguments > 0)
		{
		type_number = func->ArgTypes[0];
		}
	else 
		{
		// don't think it ever will get here since 'set' always (?) has arguments, and 'add' always (?) has arguments
		type_number = func->ReturnType;
		}
	/* only print for ones that take arguments in the add functions and take none for sets */
	if ((func->NumberOfArguments != 1 && strncmp(func->Name,"Set", 3) != 0))
		{
		return 0;
		}
/*
	if (strcmp(func->Name, "SetOutput") == 0 || strcmp(func->Name, "SetInput") == 0) // don't want any real input/output
		{
		return 1;
		}
*/
	/*checking type so can decide if it is input or parameter.  Need object type to put into input.*/
	if ((type_number & 0xF) == 0x9)
		{
		/* make it so that if starts with add/set will put into input. */
		indent(fp, indentation);
		fprintf(fp, "<Input>\n");
		indentation++;
		indent(fp, indentation);
		fprintf(fp, "<Input_Name>");
		fprintf(fp, "%s", func->Name+3);  // +3 so don't get Add/Set
		fprintf(fp, "</Input_Name>\n");
		indent(fp, indentation);
		fprintf(fp, "<Input_Type>");
		fprintf(fp, "%s", func->ArgClasses[0]);
		fprintf(fp, "</Input_Type>\n");
		/*all functions that are of type "Add" can be used as inputs multiple times or none at all, so flagged as
		Optional and Repeatable. */
		if (strncmp(func->Name, "Add", 3) == 0)
			{
			indent(fp, indentation);
			fprintf(fp, "<Input_Flags>Repeatable,Optional</Input_Flags>\n");
			}
		/* all functions that are of type "Set" can be used or ignored, so flagged as Optional. */
		if (strncmp(func->Name, "Set",3) == 0)
			{
			indent(fp, indentation);
			fprintf(fp, "<Input_Flags>Optional</Input_Flags>\n");
			}
		indentation--;
		indent(fp, indentation);
		fprintf(fp, "</Input>\n");
		value = 1;
		}
	return value;
	}
/*Print out a function as a parameter type in XML format*/
int ParameterFunctions(FILE *fp, FunctionInfo *func, int indentation)
	{
	int i = 0, type_number, total_arguments = 0; 
	if (func->NumberOfArguments > 0)
		{
		type_number = func->ArgTypes[0];
		}
	else 
		{
		// don't think it ever will get here since 'set' always (?) has arguments, and 'add' always (?) has arguments
		type_number = func->ReturnType;
		}
		/*checking if it is primitive type*/
	if (((type_number & 0x000F) == 0x1 ||
		  (type_number & 0x000F) == 0x3 ||
			(type_number & 0x000F) == 0x4 ||
			(type_number & 0x000F) == 0x5 ||
			(type_number & 0x000F) == 0x6 ||
			(type_number & 0x000F) == 0x7 ||
			(type_number & 0x000F) == 0xD ||
			(type_number & 0x000F) == 0xE))
		{
		for (i = 0; i < func->NumberOfArguments; i ++)
			{
			if ((type_number & 0x0F00) == 0x300 && !func->ArgCounts[i]) // is an array and doesn't have number of arguments that array takes
				{
				total_arguments = -1;  // array size is undetermined (ex. for char*)
				break;
				}
			else if ((type_number & 0x0F00) == 0x300)  // is an array and lists the number of expected parameters (ex. center wants 3 parameters)
				{
				total_arguments += func->ArgCounts[i];
				}
			else //just a simple scalar so figure out how many scalars it wants
				{
				total_arguments += 1;
				}
			}
		if ((type_number & 0x000F) == 0x3 || total_arguments != -1) // it's a char or it has a known array size (ex. not int* with unknown size)
			{
			indent(fp, indentation);
			fprintf(fp, "<Parameter>\n");
			indentation++;
			indent(fp, indentation);
			fprintf(fp, "<Parameter_Name>%s</Parameter_Name>\n", func->Name+3);
			indent(fp, indentation);
			fprintf(fp, "<Parameter_Type>");
			if ((type_number & 0x00F0) == 0x0010) /* unsigned */
				{
				fprintf(fp, "unsigned ");
				}
			switch (type_number & 0x000F)
				{
				case 0x1: /* float */
					fprintf(fp, "float");
					break;
				case 0x3: /* char */
					fprintf(fp, "char");
					break;
				case 0x4: /* int */
					fprintf(fp, "int");
					break;
				case 0x5: /* short */
					fprintf(fp, "short");
					break;
				case 0x6: /* long */
					fprintf(fp, "long");
					break;
				case 0x7: /* double */
					fprintf(fp, "double");
					break;

					//Don't think the next ones are wanted to be printed as they can be unsupported types
	//			case 0x8: /* unrecognized */
	//				fprintf(fp, "%s(%s)", VTKXML_UNSUPPORTED,
	//        (class_name ? class_name : "??"));
	//      break;
	//				case 0xA: /* vtkIdType */
	//#ifdef VTK_USE_64BIT_IDS
	//#if defined(VTK_TYPE_USE_LONG_LONG) && VTK_SIZEOF_LONG_LONG == 8
	//      /* use "long long" as vtkIdType */
	//      fprintf(fp, "long long");
	//#elif defined(VTK_TYPE_USE___INT64) && VTK_SIZEOF___INT64 == 8
	//      /* use "__int64" as vtkIdType */
	//      fprintf(fp, "__int64");
	//#else
	//      fprintf(fp, "%s(vtkIdType)", VTKXML_UNSUPPORTED);
	//#endif
	//#else
	//      /* use "int" as vtkIdType */
	//      fprintf(fp, "int");
	//#endif
	//      break;
	//    case 0xB: /* long long */
	//#if defined(VTK_TYPE_USE_LONG_LONG)
	//      fprintf(fp, "long long");
	//#else
	//      fprintf(fp, "%s(long long)", VTKXML_UNSUPPORTED);
	//#endif
	//      break;
	//    case 0xC: /* __int64 */
	//#if defined(VTK_TYPE_USE___INT64)
	//      fprintf(fp, "__int64");
	//#else
	//      fprintf(fp, "%s(__int64)", VTKXML_UNSUPPORTED);
	//#endif
	//      break;

				case 0xD: /* signed char */
					fprintf(fp, "signed char");
					break;
				case 0xE: /* bool */
					fprintf(fp, "bool");
					break;
				}
				fprintf(fp, "</Parameter_Type>\n");
				indent(fp, indentation);
				fprintf(fp, "<Parameter_Size>");
				/* if set function has multiple arguments, then the number of acceptable parameters is same as number of arguments */
				if (total_arguments > 0)
					{
					fprintf(fp, "%i", total_arguments);  
					}
				else
					{
					fprintf(fp, "N");  // for cases like char * where array size isn't given
					}
				fprintf(fp, "</Parameter_Size>\n");
				indentation--;
				indent(fp, indentation);
				fprintf(fp, "</Parameter>\n");
				return 1;
				}
			}
		return 0;
	}

/* print all output types.  Includes output that has been promoted from a partnerless Get Functions, as well as including 
the name of the class as a final output parameter. */
void PrintOutput(FILE *fp, char *name, char* type, int indentation)
	{
		if (strcmp(name, "Output") == 0) return; // so no real output as that will be handled by the MATLAB code and instantiated objects
		indent(fp, indentation);
		fprintf(fp, "<Output>\n");
		indentation++;
		indent(fp, indentation);
		fprintf(fp, "<Output_Name>%s</Output_Name>\n", name);
		indent(fp, indentation);
		fprintf(fp, "<Output_Type>%s</Output_Type>\n", type);
		indentation--;
		indent(fp, indentation);
		fprintf(fp, "</Output>\n");
	}

/* main functions that takes a parsed FileInfo from vtk and produces a specific vtkXML format for desired functions to be
incorporated in SimVTK (ie. certain add, remove, get and set methods). */
void vtkParseOutput(FILE *fp, FileInfo *data)
	{
	
  /* store the last element index of the add, set, remove, get arrays so easier
  when checking for stopping to compare values.  setForInputOnly is used to check if any set methods were used for 
	parameters and not just promoted inputs.  indentation is to make sure that the XML format is proper. */
	int i, setForInputOnly = -1, endOfAddFunctions = -1, endOfSetFunctions = -1, endOfRemoveFunctions = -1, endOfGetFunctions = -1, indentation = 0;
	int addFunctions[MAX_ARRAY_SIZE];  //array to store indices of the data->Functions array that are functions starting with "Add"
	int setFunctions[MAX_ARRAY_SIZE];
	int removeFunctions[MAX_ARRAY_SIZE];
	int getFunctions[MAX_ARRAY_SIZE];

	/* separate functions into functions beginning with "Add", "Remove", "Set", and "Get" here */
	separateFunctions(fp, data, addFunctions, &endOfAddFunctions, removeFunctions, &endOfRemoveFunctions, setFunctions, &endOfSetFunctions, getFunctions, &endOfGetFunctions);
	/* take only methods with both a set and get method; will make new 'set' array with
	only the right methods in them (ones useful for parameters or inputs)
	endOfSetFunctions has index of last useful function.  If endOfSetFunctions = -1, then no matching get/set
	functions were found. */
	checkMatchBetweenFirstAndSecondList(fp, data, getFunctions, &endOfGetFunctions, 3, setFunctions, &endOfSetFunctions, 3);
	/* take only methods with both an add and remove method and place in 'add' array.  Same as for above with get/set. */
	checkMatchBetweenFirstAndSecondList(fp, data, removeFunctions, &endOfRemoveFunctions, 6, addFunctions, &endOfAddFunctions, 3);
	/* sort function index lists based on alphabetical order of corresponding function name in data */
	sort(data, addFunctions, 0, endOfAddFunctions);
	sort(data, setFunctions, 0 ,endOfSetFunctions);
	/* get Functions starting with "Get" that have no corresponding "Set" function to be used as promoters. */
	getPromotedOutputs(fp, data, getFunctions, &endOfGetFunctions, setFunctions, &endOfSetFunctions);
	/* start new filter for class */
	indent(fp, indentation);
	fprintf(fp, "<Filter>\n");
	indentation++;
	 /* write the header of the file */
	indent(fp, indentation);
	fprintf(fp, "<Filter_Name>%s</Filter_Name>\n", data->ClassName);
	if (data->NumberOfSuperClasses > 0)
		{
		indent(fp, indentation);
		fprintf(fp, "<Super_Class>%s</Super_Class>\n", data->SuperClasses[0]);
		}
	 /* function handling code 
	First one is to list all inputs that come from the add, remove functions.*/
	for (i = 0; i <= endOfAddFunctions; i++)
	  {
		InputFunctions(fp, &data->Functions[addFunctions[i]], indentation);
	  }
	/* for addinng all the set functions that take vtkObjects as arguments, which have been promoted to inputs */
	for (i = 0; i <= endOfSetFunctions; i++)
		{
		setForInputOnly  += InputFunctions(fp, &data->Functions[setFunctions[i]], indentation);
		}
	/* All inputs should be added now, so only need to add parameters */
	if (setForInputOnly < endOfSetFunctions) // check if all of setFunctions were used as inputs (or none existed at start)
		{
		/* add all parameters to the XML file */
		indent(fp, indentation);
		fprintf(fp, "<Filter_Parameters>\n");
		indentation++;
		for (i = 0; i <= endOfSetFunctions; i++)
			{
			ParameterFunctions(fp, &data->Functions[setFunctions[i]], indentation);
			}
		indentation--;
		indent(fp, indentation);
		fprintf(fp, "</Filter_Parameters>\n");
		}
	sort(data, getFunctions, 0, endOfGetFunctions);
	/* print all promoted outputs in alphabetical order, then print the class name as an additional output, so can treat 
	properly to connect inputs with outputs later. (ex. vtkRenderer needs vtkMappers, and by keeping the class name
	as an output this becomes possible to link the outputs to the next input variable) */
	for (i = 0; i <= endOfGetFunctions; i++)
		{
		PrintOutput(fp, data->Functions[getFunctions[i]].Name+3, data->Functions[getFunctions[i]].ReturnClass, indentation);
		}
	PrintOutput(fp, "Self", data->ClassName, indentation);
	indentation--;
	indent(fp, indentation);
	fprintf(fp, "</Filter>\n");
}

/*stuff to do (in no particular order):
-	1a. get only set+get methods with simple arguments (no object/unknown)
-	1b. put into xml parameters
-	2a. get only set+get methods with object arguments
-	2b. put into xml inputs with optional
-	3a. get all add+remove methods
-	3b. put into xml inputs with repeatable/optional
*/
/* how to get only wanted methods:
-	1. go through function list and put all	gets, sets, adds, removes into other arrays.
-	2. for gets array - check if end in sets matches current end. if yes put current in
-	next free space in array. remove others. (use index for current and one for not used space, everything will move up or stay in place, not used will 
-	give end of useful methods).  ALSO KEEP GETOUTPUT/GETINPUT METHODS.
-	3. repeat for add/remove.
*/
/* how to get filter
	DO FOR EACH HEADER FILE
-	1. put <filter> at top
-	2. check data->classname for <filter_name>
	2b. add functions from superclasses (if either getoutput/input, or returns a primitive) to main filter class function list.
	FOR INPUTS
-	3. go through get function list and use func->returntype to check if it is a vtkObject.
-	If it is start a new <Input>, with <Input_Name> as func->name (w/out get), <Input_Type> as func->ReturnType (for get), and <Input_Flags> as optional.
-	4. go through add function list and start new <Input> similar to above, with <Input_Flags> as optional/repeatable.
-	5. add non-optional/non-repeatable inputs by checking functions for an getInput and using its return type as the type.	
	FOR PARAMETERS
-	6. start with a <filter_parameters> header
-	7. go through get function list and use func->returntype to make sure not a vtkObject.  Make <Parameter> for each.
-	8. make <parameter_name> be the func->name, make <parameter_type> be the func->returnType, and make <parameter_size> be func->ArgCount[0],1
-	 if has a hint size, otherwise use N,1.
	 FOR OUTPUTS
-	 9. check for a getOutput method - if yes use return type as output type (will need entire heirarchy done for this to work).
-	 So need to put heirarchy all together before checking for output. (or really doing anything so that easy to put all inputs and parameters together)
-	 10. if no getoutput method, then just use function name as return type.*/
	/* WHAT IT SHOULD DO
-	CHECK ARG NUMBER - WANT ONLY 1 ARG (WILL ELIMATE DUPLICATES IF ARRAY USED FOR INPUT
-			AND A MULTIPLE ARG FUNCTION EXISTS TOO)
-	CHECK ARG TYPE OF FIRST ARG
-	IF OBJECT (0x9) (INPUT),
-			NAME IS SUBSTRING OF NAME FROM INDEX 3.  (unless is setInput/Output or other exceptions)
-			TYPE IS VTK OBJECT TYPE (FROM ARGCLASSES[0])
-			FLAGS - OPTIONAL FOR ALL, REPEATABLE IF STARTS WITH ADD
-	IF NOT OBJECT (0x1,3,4,5,6,7,B,C,D,E), MUST BE USED FOR PARAMETER.
-			START WITH PARAMETER HEADER
-			NAME IS SUBSTRING OF NAME FROM INDEX 3
-			TYPE ARG TYPE OF ARG[0]
-			SIZE IS ARGCOUNTS[0] (IF ARGCOUNTS[0] indicates an unknown then SET TO N	*/
