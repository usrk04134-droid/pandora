NAMESPACE Esab.Mock
    /// Mocks a void method
    CLASS MethodMock
        VAR PRIVATE
            _callCount : UINT := UINT#0;
        END_VAR

        METHOD PUBLIC Reset
            THIS._callCount := UINT#0;
        END_METHOD

        METHOD PUBLIC GetCallCount : UINT
            GetCallCount := THIS._callCount;
        END_METHOD

        METHOD PUBLIC IncrementCallCount
            THIS._callCount := THIS._callCount + UINT#1;
        END_METHOD
    END_CLASS

    /// Mocks a method that handles a bool
    CLASS BoolMethodMock EXTENDS MethodMock
        VAR PUBLIC
            Value : BOOL;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            Value := FALSE;
            SUPER.Reset();
        END_METHOD
    END_CLASS

    /// Mocks a method that handles an Int
    CLASS IntMethodMock EXTENDS MethodMock
        VAR PUBLIC
            Value : INT;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            Value := 0;
            SUPER.Reset();
        END_METHOD
    END_CLASS

    /// Mocks a method that handles a DInt
    CLASS DIntMethodMock EXTENDS MethodMock
        VAR PUBLIC
            Value : DINT;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            Value := 0;
            SUPER.Reset();
        END_METHOD
    END_CLASS

    /// Mocks a method that handles a Real
    CLASS RealMethodMock EXTENDS MethodMock
        VAR PUBLIC
            Value : REAL;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            Value := REAL#0.0;
            SUPER.Reset();
        END_METHOD
    END_CLASS

    /// Mocks a method that handles a LReal
    CLASS LRealMethodMock EXTENDS MethodMock
        VAR PUBLIC
            Value : LREAL;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            Value := LREAL#0.0;
            SUPER.Reset();
        END_METHOD
    END_CLASS

    /// Mocks a method that handles a Byte
    CLASS ByteMethodMock EXTENDS MethodMock
        VAR PUBLIC
            Value : BYTE;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            Value := BYTE#0;
            SUPER.Reset();
        END_METHOD
    END_CLASS

    /// Mocks a method that handles an UInt
    CLASS UIntMethodMock EXTENDS MethodMock
        VAR PUBLIC
            Value : UINT;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            Value := UINT#0;
            SUPER.Reset();
        END_METHOD
    END_CLASS

    /// Mocks a method that handles an Word
    CLASS WordMethodMock EXTENDS MethodMock
        VAR PUBLIC
            Value : WORD;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            Value := WORD#0;
            SUPER.Reset();
        END_METHOD
    END_CLASS

    /// Mocks a method with (REAL, INT) arguments
    CLASS RealIntMethodMock EXTENDS MethodMock
        VAR PUBLIC
            Value1 : REAL;
            Value2 : INT;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            SUPER.Reset();
            Value1 := REAL#0.0;
            Value2 := 0;
        END_METHOD
    END_CLASS

    /// Mocks a method with (BYTE, INT) arguments
    CLASS ByteIntMethodMock EXTENDS MethodMock
        VAR PUBLIC
            Value1 : BYTE;
            Value2 : INT;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            SUPER.Reset();
            Value1 := BYTE#0;
            Value2 := 0;
        END_METHOD
    END_CLASS

    /// Mocks a method with (UINT, INT) arguments
    CLASS UIntIntMethodMock EXTENDS MethodMock
        VAR PUBLIC
            Value1 : UINT;
            Value2 : INT;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            SUPER.Reset();
            Value1 := UINT#0;
            Value2 := 0;
        END_METHOD
    END_CLASS

    /// Mocks a method with (INT, INT) arguments
    CLASS IntIntMethodMock EXTENDS MethodMock
        VAR PUBLIC
            Value1 : INT;
            Value2 : INT;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            SUPER.Reset();
            Value1 := 0;
            Value2 := 0;
        END_METHOD
    END_CLASS

    /// Mocks a method with (INT, BOOL) arguments
    CLASS IntBoolMethodMock EXTENDS MethodMock
        VAR PUBLIC
            Value1 : INT;
            Value2 : BOOL;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            SUPER.Reset();
            Value1 := 0;
            Value2 := FALSE;
        END_METHOD
    END_CLASS

    /// Mocks a method with (INT, LREAL) arguments
    CLASS IntLRealMethodMock EXTENDS MethodMock
        VAR PUBLIC
            Value1 : INT;
            Value2 : LREAL;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            SUPER.Reset();
            Value1 := 0;
            Value2 := 0.0;
        END_METHOD
    END_CLASS

END_NAMESPACE