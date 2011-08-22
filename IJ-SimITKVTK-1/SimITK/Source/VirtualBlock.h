/******************************************************************************
SIMITK Project

Copyright (c) Queen's University
All rights reserved.

See Copyright.txt for more details.

Karen Li and Jing Xiang
June 2008

VirtualBlock.h
******************************************************************************/
#include "VirtualPort.h"
#include "VirtualSpecialPort.h"
#include <vector>

template <class InputPortType, class OutputPortType>
class VirtualBlock {

public:
	// Constructor and destructor
	VirtualBlock(){
	};
	~VirtualBlock(){};
	
	// Sets the input and output ports at the given index
	void SetInput(InputPortType input, int index){ 
		if (m_Inputs.size() < (index + 1)){
			m_Inputs.resize(index+1);
		}
		m_Inputs[index] = input; 
	};
	
	void SetOutput(OutputPortType output, int index) { 
		if (m_Outputs.size() < (index + 1)){
			m_Outputs.resize(index+1); 
		}
		m_Outputs[index] = output; 
	};
	
	void SetSpecialInput(VirtualSpecialPort specialInput, int index){
		if (m_SpecialInputs.size() < (index +1)){
			m_SpecialInputs.resize(index+1);
		}
		m_SpecialInputs[index] = specialInput;
	};
	
	void SetSpecialOutput(VirtualSpecialPort specialOutput, int index){
		if (m_SpecialOutputs.size() < (index +1)){
			m_SpecialOutputs.resize(index+1);
		}
		m_SpecialOutputs[index] = specialOutput;
	};

	// Returns the VirtualPort at a given index for the input and output ports
	InputPortType& GetInput(int index){ return m_Inputs.at(index); };
	const InputPortType& GetInput(int index) const { return m_Inputs.at(index); };
	OutputPortType& GetOutput(int index){ return m_Outputs.at(index); };
	const OutputPortType& GetOutput(int index) const { return m_Outputs.at(index); };
	VirtualSpecialPort& GetSpecialInput(int index){ return m_SpecialInputs.at(index); };
	const VirtualSpecialPort& GetSpecialInput(int index) const { return m_SpecialInputs.at(index); };
	VirtualSpecialPort& GetSpecialOutput(int index){ return m_SpecialOutputs.at(index); };
	const VirtualSpecialPort& GetSpecialOutput(int index) const { return m_SpecialOutputs.at(index); };
	
	// Virtual method that Matlab calls to update ITK
	virtual void Run() = 0;
	
// Changed from protected to private
protected:
	// Vectors for input and output ports
	std::vector<InputPortType> m_Inputs;
	std::vector<OutputPortType> m_Outputs;
	std::vector<VirtualSpecialPort> m_SpecialInputs;
	std::vector<VirtualSpecialPort> m_SpecialOutputs;

};




