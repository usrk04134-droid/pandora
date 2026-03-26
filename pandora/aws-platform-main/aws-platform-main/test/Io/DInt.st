USING Esab.Io.Mock;

USING AxUnit;

NAMESPACE Esab.Io.Test

    {TestFixture}
    {Category(IO)}
    CLASS DIntInputTests
        VAR PRIVATE
            _value : BOOL;
            _input : DIntInput;
            _changedHandler : DIntInputChangedListenerMock;
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
            // Read two times to reset state.
            _input.Endianness := Endianness#Big;
            _input.Read(0);
            _input.Read(0);
        END_METHOD

        {Test}
        METHOD PUBLIC ReadBigEndian
            _input.Read(DINT#16#11121314);
            Assert.Equal(_input.GetValue(), DINT#16#11121314);
            _input.Read(0);
            Assert.Equal(_input.GetValue(), 0);
        END_METHOD

        {Test}
        METHOD PUBLIC ReadLittleEndian
            _input.Endianness := Endianness#Little;
            _input.Read(DINT#16#11121314);
            Assert.Equal(_input.GetValue(), DINT#16#14131211);
            _input.Read(0);
            Assert.Equal(_input.GetValue(), 0);
        END_METHOD

        {Test}
        METHOD PUBLIC GetValue
            _input.Read(25);
            Assert.Equal(_input.GetValue(), 25);
            _input.Read(0);
            Assert.Equal(_input.GetValue(), 0);
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
    CLASS DIntOutputTests
        VAR PRIVATE
            _outputValue : DINT;
            _output : DintOutput;
        END_VAR

        {FixtureSetup}
        METHOD PUBLIC TestFixtureSetup
            ;
        END_METHOD

        {TestSetup}
        METHOD PUBLIC TestSetup
            _outputValue := 0;
            _output.Endianness := Endianness#Big;
            _output.SetValue(_outputValue);
        END_METHOD

        {Test}
        METHOD PUBLIC WriteBigEndian
            _output.SetValue(DINT#16#11121314);
            _output.Write(_outputValue);

            Assert.Equal(_outputValue, DINT#16#11121314);
        END_METHOD

        {Test}
        METHOD PUBLIC WriteLittleEndian
            _output.Endianness := Endianness#Little;
            _output.SetValue(DINT#16#11121314);
            _output.Write(_outputValue);

            Assert.Equal(_outputValue, DINT#16#14131211);
        END_METHOD

        {Test}
        METHOD PUBLIC SetValue
            _output.SetValue(25);
            _output.Write(value => _outputValue);

            Assert.Equal(_outputValue, 25);

            _output.SetValue(0);
            _output.Write(value => _outputValue);

            Assert.Equal(_outputValue, 0);
        END_METHOD
    END_CLASS

    CLASS DIntInputChangedListenerMock IMPLEMENTS InputChangedListener
        VAR PUBLIC
            Id : UINT;
            Value : DINT;
        END_VAR

        METHOD PUBLIC InputChanged
            VAR_INPUT
                input : REF_TO Input;
            END_VAR

            VAR_TEMP
                _input : REF_TO DIntInput;
            END_VAR

            _input ?= input;

            IF _input <> NULL THEN
                Id := _input^.Id;
                Value := _input^.GetValue();
            END_IF;
        END_METHOD
    END_CLASS

END_NAMESPACE