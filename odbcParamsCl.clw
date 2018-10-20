
  member()
  
  include('odbcParamsCl.inc'),once 
  include('odbcSqlStrCl.inc'),once
  
  map 
    module('odbc32')
      SQLBindParameter(SQLHSTMT StatementHandle, SQLUSMALLINT ParameterNumber, SQLSMALLINT InputOutputType, SQLSMALLINT ValueType, SQLSMALLINT ParameterType, SQLULEN ColumnSize, SQLSMALLINT DecimalDigits, SQLPOINTER ParameterValuePtr, SQLLEN BufferLength, *SQLLEN StrLen_or_IndPtr)sqlReturn,pascal      
    end 
    module('c6')
      memmove(long dest, long src, long num),long,proc,name('_memmove')
      strLen(long cstr),long,name('_strlen')
    end 
  end

! ---------------------------------------------------------------------------
  
ParametersClass.construct procedure()

  code 

  self.init() 
      
  return
! end construct
! ----------------------------------------------------------------------------

ParametersClass.Init procedure()

retv     byte,auto 

  code 
  
  if (self.paramQ &= null) 
    self.paramQ &= new(ParametersQueue)
    if (self.paramQ &= null) 
      retv = level:notify  
      self.setupFailed = true
    else 
      self.setupFailed = false  
    end 
  end   
  
  return retv
! end init 
! ------------------------------------------------------------------------------------
  
ParametersClass.kill procedure()

  code
    
  if (self.setupFailed = false) 
    free(self.paramQ)
    dispose(self.paramQ)
    self.paramQ &= null
    self.setupFailed = true
  end  
  
  return 
! end kill 
! -----------------------------------------------------------------------------
    
ParametersClass.destruct procedure()

  code 
  
  self.kill() 
  
  return
! destruct 
! -----------------------------------------------------------------------------

! -----------------------------------------------------------------------------
! bindParameters
! Bind parameters for the statement.  A parameter in a sql statement is marked with a ? 
! this process binds the actual parameter to that place holder so the back end knows 
! what is going on.   The order the parameters are added to the queue MUST match the order 
! ? marks appear in the sql statement.  There is no mapping by name. 
! If a parameter appears in the statement twice or multiple times it must also be in the 
! queue twice or how ever many times. 
! 
! parameters for the ODBC api call 
! hStmt   = handle to the ODBC statement
! paramId = ord value of the parmaeter, 1, 2, 3 ... the ordinal position
! InOutType = type of parmeter in/out/inout
! value type = the C data type of the parameter, an equate value from the API
! param type = the sql data type of the parameter, an equate value from the API
! param size = the size, in bytes of the column for this parameter typicall the same as the paraLength
! decimal digits = number of decimal of the column 
! ParamPtr = pointer to the data for the parameter
! paramLength = the size of the paramPtr buffer
! colInd = pointer to a buffer for the size of the parameter.   not used and null in this example 
! -----------------------------------------------------------------------------  
ParametersClass.bindParameters procedure(SQLHSTMT hStmt) !,sqlReturn  

colInd   &long       ! null pointer, param not used in this example
retv     sqlReturn   
count    long,auto
recCount long,auto

  code 

  if (self.setupFailed = true) 
    return sql_error
  end   
  
  recCount = records(self.paramQ)
  ! once for each parameter
  loop count = 1 to recCount
    get(self.paramQ, count)
    retv = SQLBindParameter(hStmt, self.paramQ.ParamId, self.paramQ.InOutType, self.paramQ.valueType, self.paramQ.ParamType, self.paramQ.paraSize, self.paramQ.DecimalDigits, self.paramQ.ParamPtr, self.paramQ.paramLength, colInd)
    ! if not a good call then get out, if one is missing the rest do not matter
    if (retv <> sql_Success) and (retv <> Sql_Success_with_info)
      break
    end  
  end    
  ! reset for the caller
  if (retv = Sql_Success_with_info)
    retv = Sql_Success
  end
    
  return retv
! end bindParameters 
! ---------------------------------------------------------------------------------

ParametersClass.bindParameters procedure(SQLHSTMT hStmt, *sqlStrClType sqlStr) !,sqlReturn  

colInd      &long       ! null pointer, param not used in this example
retv        sqlReturn   
paramCount  long(0)
ss          &cstring

  code 

  if (instring(eParamIdChar, sqlStr.sqlStr.str(), 1, 1) <= 0)
    retv = self.bindParameters(hStmt)
    if (retv <> sql_success)
      return sql_Error
    end
  else   
    ss &= new(cstring(sqlstr.sqlStr.strLen() + 1))
    ss = sqlstr.sqlStr.cstr()
  
    loop 
      paramCount = sqlstr.replaceName(self, ss)
      if (paramCount > 0)
        retv = SQLBindParameter(hStmt, paramCount, self.paramQ.InOutType, self.paramQ.valueType, self.paramQ.ParamType, self.paramQ.paraSize, self.paramQ.DecimalDigits, self.paramQ.ParamPtr, self.paramQ.paramLength, colInd)    
        if (retv <> sql_Success) and (retv <> sql_Success_with_info)
          break
        end 
      else 
        break
      end     
    end       
 
    sqlstr.replaceStr(ss)
    dispose(ss)
  end 
  
  if (retv = sql_success_with_info) 
    retv = sql_Success
  end
    
  return retv
! end bindParameters 
! ---------------------------------------------------------------------------------

ParametersClass.clearQ procedure()

  code 
  
  if (self.setupFailed = false)
    free(self.paramQ)
  end

  return
! end clear
! ---------------------------------------------------------------------------------

ParametersClass.addParameter procedure(SQLSMALLINT InOutType, SQLSMALLINT ValueType, | 
                                       SQLSMALLINT ParameterType, SQLULEN ColumnSize, | 
                                       SQLSMALLINT DecimalDigits, SQLPOINTER varPtr, | 
                                       SQLLEN BufferLength) !,byte,proc,private

retv     byte(level:benign)

  code 
  
  if (self.setupFailed = true) 
    return sql_error
  end   
  
  self.paramQ.paramId = records(self.ParamQ) + 1
  self.paramQ.InOutType = inOutType
  self.paramQ.valueType = ValueType
  self.paramQ.paramType = ParameterType
  self.paramQ.paraSize = ColumnSize
  self.paramQ.DecimalDigits = DecimalDigits
  self.paramQ.ParamPtr = varPtr
  self.paramQ.paramLength = BufferLength

  add(self.paramQ)
  
  if (errorcode() > 0) 
    retv = level:notify
  end 
      
  return retv
! end addParameter
! ------------------------------------------------------------------------------------

ParametersClass.addParameter procedure(string paramName, |
                                       SQLSMALLINT InOutType, SQLSMALLINT ValueType, | 
                                       SQLSMALLINT ParameterType, SQLULEN ColumnSize, | 
                                       SQLSMALLINT DecimalDigits, SQLPOINTER varPtr, | 
                                       SQLLEN BufferLength) !,byte,proc,private

retv     byte,auto 

   code 
   
   retv = self.addParameter(InOutType, ValueType, ParameterType, ColumnSize, DecimalDigits, varPtr, BufferLength)
   if (retv = level:benign) 
     self.paramQ.paramName = upper(paramName)
     put(self.paramQ) 
   end
     
   return retv 
! end addParameter
! ------------------------------------------------------------------------------------

ParametersClass.AddInParameter procedure(*long varPtr)

retv   sqlReturn

  code

  self.addParameter(SQL_PARAM_INPUT, SQL_C_SLONG, SQL_INTEGER, eSizeLong, 0, address(varPtr), eSizeLong)

  return retv  
! end AddInParameter
! --------------------------------------------------------------------------------

ParametersClass.AddInParameter procedure(string pName, *long varPtr) !,sqlReturn,proc

retv   sqlReturn

  code 
  
  self.addParameter(pName, SQL_PARAM_INPUT, SQL_C_SLONG, SQL_INTEGER, eSizeLong, 0, address(varPtr), eSizeLong)
  
  return retv
   
ParametersClass.AddInParameter procedure(*real varPtr) !,sqlReturn,proc

retv   sqlReturn

  code

  self.addParameter(SQL_PARAM_INPUT, SQL_C_DOUBLE, SQL_FLOAT, eSizeReal, 0, address(varPtr), eSizeReal)

  return retv  
! end AddInParameter
! --------------------------------------------------------------------------------

ParametersClass.AddInParameter procedure(string pName, *real varPtr) !,sqlReturn,proc

retv   sqlReturn

  code

  self.addParameter(pName, SQL_PARAM_INPUT, SQL_C_DOUBLE, SQL_FLOAT, eSizeReal, 0, address(varPtr), eSizeReal)

  return retv  
! end AddInParameter
! --------------------------------------------------------------------------------

ParametersClass.AddInParameter procedure(*string varPtr) !,sqlReturn,proc

retv   sqlReturn

  code

  self.addParameter(SQL_PARAM_INPUT, SQL_C_CHAR, SQL_CHAR, size(varPtr), 0, address(varPtr), size(varPtr))
  
  return retv  
! end AddInParameter
! --------------------------------------------------------------------------------

ParametersClass.AddInParameter procedure(string pName, *string varPtr) !,sqlReturn,proc

retv   sqlReturn

  code

  self.addParameter(pName, SQL_PARAM_INPUT, SQL_C_CHAR, SQL_CHAR, size(varPtr), 0, address(varPtr), size(varPtr))
  
  return retv  
! end AddInParameter
! --------------------------------------------------------------------------------

ParametersClass.AddInParameter procedure(*TIMESTAMP_STRUCT varPtr) !,sqlReturn,proc  

retv   sqlReturn

  code

  self.addParameter(SQL_PARAM_INPUT, SQL_C_TYPE_TIMESTAMP, SQL_TYPE_TIMESTAMP, size(SQL_C_TYPE_TIMESTAMP), 0, address(varPtr), size(SQL_C_TYPE_TIMESTAMP))

  return retv    
! end AddInParameter
! --------------------------------------------------------------------------------  

ParametersClass.AddInParameter procedure(string pName, *TIMESTAMP_STRUCT varPtr) !,sqlReturn,proc  

retv   sqlReturn,auto

  code

  retv = self.addParameter(pName, SQL_PARAM_INPUT, SQL_C_TYPE_TIMESTAMP, SQL_TYPE_TIMESTAMP, size(SQL_C_TYPE_TIMESTAMP), 0, address(varPtr), size(SQL_C_TYPE_TIMESTAMP))

  return retv    
! end AddInParameter
! --------------------------------------------------------------------------------  

ParametersClass.FillPlaceHolders procedure(sqlStrClType sqlCode) 

count    long
recCount long

  code 
  
  recCount = records(self.paramQ)
  loop count = 1 to recCount 
    get(self.paramQ, count)
    if (count < recCount)
      sqlCode.cat(eMarkerComma)
    else 
      sqlCode.cat(eFinalMarker)
    end 
  end       

  return recCount

ParametersClass.findByParamName procedure(string pName) !,sqlReturn

retv   sqlReturn(sql_Success)

  code 

  self.paramQ.paramName = upper(pName)
  get(self.paramQ, +self.paramQ.paramName)
  if (errorcode() > 0)
    retv = sql_Error
  end  
  
  return retv