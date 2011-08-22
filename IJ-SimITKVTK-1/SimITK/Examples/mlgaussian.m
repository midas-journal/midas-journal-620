function mlgaussian(block)
% Level-2 M file S-function for applying Sobel filtering  
% (image edge detection demonstration).
%   Copyright 1990-2005 The MathWorks, Inc.
%   $Revision: 1.1.6.3 $    
  
  setup(block);

%endfunction

function setup(block)
  
  %% Register dialog parameter: edge direction 
  block.NumDialogPrms = 1;
  block.DialogPrmsTunable = {'Tunable'};
 
  %% Register ports
  block.NumInputPorts  = 1;
  block.NumOutputPorts = 1;
  
  %% Setup port properties
  block.SetPreCompInpPortInfoToDynamic;
  block.SetPreCompOutPortInfoToDynamic;

  block.InputPort(1).DatatypeID   = 1;
  block.InputPort(1).Complexity   = 'Real';
  block.InputPort(1).SamplingMode = 'Sample';
  block.InputPort(1).Overwritable = false; % No in-place operation
  
  block.OutputPort(1).DatatypeID   = 1;
  block.OutputPort(1).Complexity   = 'Real';
  block.OutputPort(1).SamplingMode = 'Sample';
  
  %% Register block methods (through MATLAB function handles)
  block.RegBlockMethod('Outputs', @Output);
  block.RegBlockMethod('WriteRTW',@WriteRTW);

  %% Block runs on TLC in accelerator mode.
  block.SetAccelRunOnTLC(true);

%endfunction

function  g = gaussian_filt(f, dir)

  h=fspecial('gaussian',[13 13],0.9);
  g=filter2(h,f);
  
%%
%% Block Output method: Perform Sobel filtering
%%
function Output(block)
  
  dir = block.DialogPrm(1).Data;
  block.OutputPort(1).Data = gaussian_filt(block.InputPort(1).Data, dir);
%endfunction

function WriteRTW(block)

  dir = sprintf('%d',block.DialogPrm(1).Data);
  
  block.WriteRTWParam('string', 'Direction', dir);

%endfunction

