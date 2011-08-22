/******************************************************************************
SIMITK Project

Copyright (c) Queen's University
All rights reserved.

See Copyright.txt for more details.

Karen Li and Jing Xiang
June 2008

VirtualSpecialPort.h

Contains a pointer which references an ITK special object type. 
******************************************************************************/

class VirtualSpecialPort{

public:

	// Constructor and destructor
	VirtualSpecialPort(){};
	~VirtualSpecialPort(){};

	void SetPointer(void* pointer){
		m_Pointer = pointer;
	};
	
	void* GetPointer(){
		return m_Pointer;
	};
	
private:

	void* m_Pointer;
	
};

