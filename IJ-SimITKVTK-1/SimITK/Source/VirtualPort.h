/******************************************************************************
SIMITK Project

Copyright (c) Queen's University
All rights reserved.

See Copyright.txt for more details.

Karen Li and Jing Xiang
June 2008

VirtualPort.cpp

T refers to datatype
N refers to number of dimensions
******************************************************************************/
template <class T, unsigned int N>
class VirtualPort {

public:

	typedef T PixelType;
	static const unsigned int ImageDimension = N;

	// Constructor and destructor
	VirtualPort(){};
	~VirtualPort(){};

	void SetArray(T* array){ m_Array = array; };
	T* GetArray(){ return m_Array; };
	void SetSize(unsigned int* size){ 
		for (int i=0; i<ImageDimension; i++){
			m_Size[i] = size[i];
		}
	};
	unsigned int* GetSize(){ return m_Size; };
	void SetOrigin(double* origin){ 
		for (int i=0; i<ImageDimension; i++){
			m_Origin[i] = origin[i];
		}
	 };
	double* GetOrigin(){ return m_Origin; };
	void SetSpacing(double* spacing){ 
		for (int i=0; i<ImageDimension; i++){
			m_Spacing[i] = spacing[i];
		}
	};
	double* GetSpacing(){ return m_Spacing; };
	
private:
	T* m_Array;
	unsigned int m_Size[N];
	double m_Origin[N];
	double m_Spacing[N];
};
