USING Esab.Io.Mock;

USING AxUnit;

NAMESPACE Esab.Io.Test

    {TestFixture}
    {Category(IO)}
    CLASS RealInputTests
        VAR PRIVATE
            _value : BOOL;
            _input : RealInput;
            _changedHandler : RealInputChangedListenerMock;
        END_VAR

        {FixtureSetup}
        METHOD PUBLIC TestFixtureSetup
            ;
        END_METHOD

        {TestSetup}
        METHOD PUBLIC TestSetup
            _changedHandler.Id := UINT#0;
            _changedHandler.Value := 0;
            _input.Id := UINT#0;
            _input.Scale := REAL#1.0;
            _input.Endianness := Endianness#Big;
            // Read two times to reset state.
            _input.Read(0);
            _input.Read(0);
        END_METHOD

        {Test}
        METHOD PUBLIC ReadBigEndian
            _input.Read(DWORD#16#11121314);
            Assert.Equal(TO_DWORD(_input.GetValue()), DWORD#16#11121314);
        END_METHOD

        {Test}
        METHOD PUBLIC ReadLittleEndian
            _input.Endianness := Endianness#Little;
            _input.Read(DWORD#16#11121314);
            Assert.Equal(TO_DWORD(_input.GetValue()), DWORD#16#14131211);
        END_METHOD

        {Test}
        METHOD PUBLIC ReadRealWithScaling
            _input.Scale := REAL#0.01;
            _input.Read(REAL#100.0);
            Assert.InRange(_input.GetValue(), REAL#1.0, REAL#0.001);
        END_METHOD

        {Test}
        METHOD PUBLIC ReadDwordWithScaling
            _input.Scale := REAL#0.01;
            _input.Read(TO_DWORD(REAL#100.0));
            Assert.InRange(_input.GetValue(), REAL#1.0, REAL#0.001);
        END_METHOD

        {Test}
        METHOD PUBLIC ReadUIntWithScaling
            _input.Scale := REAL#0.01;
            _input.Read(UINT#100);
            Assert.InRange(_input.GetValue(), REAL#1.0, REAL#0.001);
        END_METHOD

        {Test}
        METHOD PUBLIC ReadIntWithScaling
            _input.Scale := REAL#0.01;
            _input.Read(INT#100);
            Assert.InRange(_input.GetValue(), REAL#1.0, REAL#0.001);
        END_METHOD

        {Test}
        METHOD PUBLIC HasChanged
            _input.Read(25);
            Assert.Equal(_input.GetValue(), 25);
            _input.Read(50);
            Assert.Equal(_input.HasChanged(), TRUE);
        END_METHOD

        {Test}
        METHOD PUBLIC OnChanged
            _input.Id := UINT#255;
            _input.SetChangedHandler(_changedHandler);

            _input.Read(0);
            _input.Read(25);

            Assert.Equal(_input.GetValue(), 25);
            Assert.Equal(_changedHandler.Id, UINT#255);
            Assert.Equal(_changedHandler.Value, 25);
        END_METHOD
    END_CLASS

    {TestFixture}
    {Category(IO)}
    CLASS RealOutputTests
        VAR PRIVATE
            _outputValue : REAL;
            _output : RealOutput;
        END_VAR

        {FixtureSetup}
        METHOD PUBLIC TestFixtureSetup
            ;
        END_METHOD

        {TestSetup}
        METHOD PUBLIC TestSetup
            _outputValue := 0;
            _output.Scale := REAL#1.0;
            _output.Endianness := Endianness#Big;
            _output.SetValue(_outputValue);
        END_METHOD

        {Test}
        METHOD PUBLIC WriteBigEndian
            _output.SetValue(TO_REAL(DWORD#16#11121314));
            _output.Write(_outputValue);
            Assert.Equal(_outputValue, TO_REAL(DWORD#16#11121314));
        END_METHOD

        {Test}
        METHOD PUBLIC WriteLittleEndian
            _output.Endianness := Endianness#Little;
            _output.SetValue(TO_REAL(DWORD#16#11121314));
            _output.Write(_outputValue);

            Assert.Equal(_outputValue, TO_REAL(DWORD#16#14131211));
        END_METHOD

        {Test}
        METHOD PUBLIC WriteRealWithScaling
            VAR_TEMP
                value : REAL;
            END_VAR

            _output.Scale := REAL#0.01;
            _output.SetValue(REAL#3.14);
            _output.Write(value);
            Assert.InRange(value, REAL#314.0, REAL#0.001);
        END_METHOD

        {Test}
        METHOD PUBLIC WriteDWordWithScaling
            VAR_TEMP
                value : DWORD;
            END_VAR

            _output.Scale := REAL#0.01;
            _output.SetValue(REAL#3.14);
            _output.Write(value);
            Assert.InRange(TO_REAL(value), REAL#314.0, REAL#0.001);
        END_METHOD

        {Test}
        METHOD PUBLIC WriteUIntWithScaling
            VAR_TEMP
                value : UINT;
            END_VAR

            _output.Scale := REAL#0.01;
            _output.SetValue(REAL#3.14);
            _output.Write(value);
            Assert.Equal(value, UINT#314);
        END_METHOD

        {Test}
        METHOD PUBLIC WriteIntWithScaling
            VAR_TEMP
                value : INT;
            END_VAR

            _output.Scale := REAL#0.01;
            _output.SetValue(REAL#3.14);
            _output.Write(value);
            Assert.Equal(value, INT#314);
        END_METHOD

        {Test}
        METHOD PUBLIC SetValue
            _output.SetValue(16);
            _output.Write(value => _outputValue);

            Assert.Equal(_outputValue, 16);

            _output.SetValue(0);
            _output.Write(value => _outputValue);

            Assert.Equal(_outputValue, 0);
        END_METHOD
    END_CLASS

    {TestFixture}
    {Category(IO)}
    CLASS RealNormalizedInputTests
        VAR PRIVATE
            _inputValue : REAL;
            _input : RealNormalizedInput;
        END_VAR

        {FixtureSetup}
        METHOD PUBLIC TestFixtureSetup
            ;
        END_METHOD

        {TestSetup}
        METHOD PUBLIC TestSetup
            _inputValue := 0;
            _input.Endianness := Endianness#Big;
            _input.Bipolar := FALSE;
            _input.Minimum := REAL#0.0;
            _input.Maximum := REAL#27648.0;
            _input.Read(_inputValue);
        END_METHOD

        {Test}
        METHOD PUBLIC ReadNormalizedWithDefaults
            _input.Read(27648);

            _inputValue := _input.GetValue();

            Assert.InRange(_inputValue, 1.0, 0.001);

            _input.Read(13824);

            _inputValue := _input.GetValue();

            Assert.InRange(_inputValue, 0.5, 0.001);

            _input.Read(0);

            _inputValue := _input.GetValue();

            Assert.InRange(_inputValue, 0.0, 0.001);
        END_METHOD

        {Test}
        METHOD PUBLIC ReadNormalizedBipolar
            _input.Bipolar := TRUE;
            _input.Minimum := -REAL#27648.0;
            _input.Maximum := REAL#27648.0;

            _input.Read(27648);

            _inputValue := _input.GetValue();

            Assert.InRange(_inputValue, 1.0, 0.001);

            _input.Read(0);

            _inputValue := _input.GetValue();

            Assert.InRange(_inputValue, 0.0, 0.001);

            _input.Read(-27648);

            _inputValue := _input.GetValue();

            Assert.InRange(_inputValue, -1.0, 0.001);
        END_METHOD
    END_CLASS

    {TestFixture}
    {Category(IO)}
    CLASS RealNormalizedOutputTests
        VAR PRIVATE
            _outputValue : INT;
            _output : RealNormalizedOutput;
        END_VAR

        {FixtureSetup}
        METHOD PUBLIC TestFixtureSetup
            ;
        END_METHOD

        {TestSetup}
        METHOD PUBLIC TestSetup
            _outputValue := 0;
            _output.Endianness := Endianness#Big;
            _output.Bipolar := FALSE;
            _output.Minimum := REAL#0.0;
            _output.Maximum := REAL#27648.0;
            _output.SetValue(0);
        END_METHOD

        {Test}
        METHOD PUBLIC WriteNormalizedWithDefaults
            _output.SetValue(REAL#1.0);
            _output.Write(_outputValue);
            Assert.InRange(_outputValue, 27648, 0.001);

            _output.SetValue(REAL#0.5);
            _output.Write(_outputValue);
            Assert.InRange(_outputValue, 27648/2, 0.001);

            _output.SetValue(REAL#0.0);
            _output.Write(_outputValue);
            Assert.InRange(_outputValue, 0, 0.001);
        END_METHOD

        {Test}
        METHOD PUBLIC WriteNormalizedBipolar
            _output.Bipolar := TRUE;
            _output.Minimum := -REAL#27648.0;
            _output.Maximum := REAL#27648.0;

            _output.SetValue(REAL#1.0);
            _output.Write(_outputValue);
            Assert.InRange(_outputValue, 27648, 0.001);

            _output.SetValue(REAL#0.5);
            _output.Write(_outputValue);
            Assert.InRange(_outputValue, 27648/2, 0.001);

            _output.SetValue(REAL#0.0);
            _output.Write(_outputValue);
            Assert.InRange(_outputValue, 0, 0.001);

            _output.SetValue(REAL#-0.5);
            _output.Write(_outputValue);
            Assert.InRange(_outputValue, -27648/2, 0.001);

            _output.SetValue(REAL#-1.0);
            _output.Write(_outputValue);
            Assert.InRange(_outputValue, -27648, 0.001);
        END_METHOD

        {Test}
        METHOD PUBLIC WriteLargerThan1
            _output.SetValue(REAL#10.0);
            _output.Write(_outputValue);
            Assert.InRange(_outputValue, 27648, 0.001);
        END_METHOD
    END_CLASS

    CLASS RealInputChangedListenerMock IMPLEMENTS InputChangedListener
        VAR PUBLIC
            Id : UINT;
            Value : REAL;
        END_VAR

        METHOD PUBLIC InputChanged
            VAR_INPUT
                input : REF_TO Input;
            END_VAR

            VAR_TEMP
                _input : REF_TO RealInput;
            END_VAR

            _input ?= input;

            IF _input <> NULL THEN
                Id := _input^.Id;
                Value := _input^.GetValue();
            END_IF;
        END_METHOD
    END_CLASS

END_NAMESPACE