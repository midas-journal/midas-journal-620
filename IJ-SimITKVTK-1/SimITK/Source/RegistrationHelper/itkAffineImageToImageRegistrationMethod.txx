/*=========================================================================

  Program:   Insight Segmentation & Registration Toolkit
  Module:    $RCSfile: MomentRegistrator.txx,v $
  Language:  C++
  Date:      $Date: 2007/03/29 17:52:55 $
  Version:   $Revision: 1.6 $

  Copyright (c) Insight Software Consortium. All rights reserved.
  See ITKCopyright.txt or http://www.itk.org/HTML/Copyright.htm for details.

     This software is distributed WITHOUT ANY WARRANTY; without even
     the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
     PURPOSE.  See the above copyright notices for more information.

=========================================================================*/


#ifndef __AffineImageToImageRegistrationMethod_txx
#define __AffineImageToImageRegistrationMethod_txx

#include "itkAffineImageToImageRegistrationMethod.h"

namespace itk
{

template< class TImage >
AffineImageToImageRegistrationMethod< TImage >
::AffineImageToImageRegistrationMethod( void )
{
  this->SetTransform( AffineTransformType::New() );
  this->GetTypedTransform()->SetIdentity();

  this->SetInitialTransformParameters( this->GetTypedTransform()->GetParameters() );

  typename Superclass::TransformParametersScalesType scales;
  scales.set_size( this->GetTypedTransform()->GetNumberOfParameters() );
  if( scales.size() != ImageDimension * (ImageDimension + 1) )
    {
    std::cerr << "ERROR: number of parameters not standard for affine transform" << std::endl;
    }
  unsigned int scaleNum = 0;
  for(int d1=0; d1<ImageDimension; d1++)
    {
    for(int d2=0; d2<ImageDimension; d2++)
      {
      if(d1 == d2)
        {
        scales[scaleNum] = 0.02;
        }
      else
        {
        scales[scaleNum] = 0.01;
        }
      ++scaleNum;
      }
    }
  for(int d1=0; d1<ImageDimension; d1++)
    {
    scales[scaleNum] = 1.0;
    ++scaleNum;
    }
  this->SetTransformParametersScales( scales );

  this->SetTransformMethodEnum( Superclass::AFFINE_TRANSFORM );
}

template< class TImage >
AffineImageToImageRegistrationMethod< TImage >
::~AffineImageToImageRegistrationMethod( void )
{
}

template< class TImage >
typename AffineImageToImageRegistrationMethod< TImage >::TransformType *
AffineImageToImageRegistrationMethod< TImage >
::GetTypedTransform( void )
{
  return static_cast< TransformType  * >( Superclass::GetTransform() );
}

template< class TImage >
typename AffineImageToImageRegistrationMethod< TImage >::AffineTransformType::Pointer
AffineImageToImageRegistrationMethod< TImage >
::GetAffineTransform( void )
{   
  typename AffineTransformType::Pointer trans = AffineTransformType::New();

  trans->SetIdentity();
  trans->SetCenter( this->GetTypedTransform()->GetCenter() );
  trans->SetMatrix( this->GetTypedTransform()->GetMatrix() );
  trans->SetOffset( this->GetTypedTransform()->GetOffset() );

  return trans;
}   

template< class TImage >
void
AffineImageToImageRegistrationMethod< TImage >
::PrintSelf( std::ostream & os, Indent indent ) const
{
  Superclass::PrintSelf(os, indent);
}

};

#endif 
