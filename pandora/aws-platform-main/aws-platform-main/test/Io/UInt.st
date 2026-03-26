USING Esab.Io.Mock;

USING AxUnit;

NAMESPACE Esab.Io.Test

    {TestFixture}
    {Category(IO)}
    CLASS UIntInputTests
        VAR PRIVATE
            _value : BOOL;
            _input : UIntInput;
            _listener : UIntInputChangedListenerMock;
        END_VAR

        {FixtureSetup}
        METHOD PUBLIC TestFixtureSetup
            ;
        END_METHOD

        {TestSetup}
        METHOD PUBLIC TestSetup
            _listener.Id := UINT#0;
            _listener.Value := UINT#0;
            _input.Id := UINT#0;
            // Read two times to reset state.
            _input.Endianness := Endianness#Big;
            _input.Read(UINT#0);
            _input.Read(UINT#0);
        END_METHOD

        {Test}
        METHOD PUBLIC ReadBigEndian
            _input.Read(UINT#16#1216);
            Assert.Equal(_input.GetValue(), UINT#16#1216);
        END_METHOD

        {Test}
        METHOD PUBLIC ReadLittleEndian
            _input.Endianness := Endianness#Little;
            _input.Read(UINT#16#1216);
            Assert.Equal(_input.GetValue(), UINT#16#1612);
        END_METHOD

        {Test}
        METHOD PUBLIC ReadBigEndianByte
            _input.Read(BYTE#16#16);
            Assert.Equal(_input.GetValue(), UINT#16#16);
        END_METHOD

        {Test}
        METHOD PUBLIC ReadLittleEndianByte
            _input.Endianness := Endianness#Little;
            _input.Read(BYTE#16#16);
            Assert.Equal(_input.GetValue(), UINT#16#16);
        END_METHOD

        {Test}
        METHOD PUBLIC HasChanged
            _input.Read(UINT#25);
            Assert.Equal(_input.GetValue(), UINT#25);
            _input.Read(UINT#50);
            Assert.Equal(_input.HasChanged(), TRUE);
        END_METHOD

        {Test}
        METHOD PUBLIC OnChanged
            _input.Id := UINT#255;
            _input.SetChangedHandler(_listener);

            _input.Read(UINT#0);
            _input.Read(UINT#25);

            Assert.Equal(_input.GetValue(), UINT#25);
            Assert.Equal(_listener.Id, UINT#255);
            Assert.Equal(_listener.Value, UINT#25);
        END_METHOD
    END_CLASS

    {TestFixture}
    CLASS UIntOutputTests
        VAR PRIVATE
            _outputValue : UINT;
            _output : UIntOutput;
        END_VAR

        {FixtureSetup}
        METHOD PUBLIC TestFixtureSetup
            ;
        END_METHOD

        {TestSetup}
        METHOD PUBLIC TestSetup
            _outputValue := UINT#0;
            _output.Endianness := Endianness#Big;
            _output.SetValue(_outputValue);
        END_METHOD

        {Test}
        METHOD PUBLIC WriteBigEndian
            _output.SetValue(UINT#16#1215);
            _output.Write(_outputValue);

            Assert.Equal(_outputValue, UINT#16#1215);
        END_METHOD

        {Test}
        METHOD PUBLIC WriteLittleEndian
            _output.Endianness := Endianness#Little;
            _output.SetValue(UINT#16#1215);
            _output.Write(_outputValue);

            Assert.Equal(_outputValue, UINT#16#1512);
        END_METHOD

        {Test}
        METHOD PUBLIC WriteBigEndianByte
            VAR_TEMP
                b : BYTE;
            END_VAR

            _output.SetValue(UINT#16#1215);
            _output.Write(b);

            Assert.Equal(b, BYTE#16#15);
        END_METHOD

        {Test}
        METHOD PUBLIC WriteLittleEndianByte
            VAR_TEMP
                b : BYTE;
            END_VAR

            _output.SetValue(UINT#16#1215);
            _output.Write(b);

            Assert.Equal(b, BYTE#16#15);
        END_METHOD

        {Test}
        METHOD PUBLIC SetValue
            _output.SetValue(UINT#16);
            _output.Write(value => _outputValue);

            Assert.Equal(_outputValue, UINT#16);

            _output.SetValue(UINT#0);
            _output.Write(value => _outputValue);

            Assert.Equal(_outputValue, UINT#0);
        END_METHOD
    END_CLASS

    CLASS UIntInputChangedListenerMock IMPLEMENTS InputChangedListener
        VAR PUBLIC
            Id : UINT;
            Value : UINT;
        END_VAR

        METHOD PUBLIC InputChanged
            VAR_INPUT
                input : REF_TO Input;
            END_VAR

            VAR_TEMP
                _input : REF_TO UIntInput;
            END_VAR

            _input ?= input;

            IF _input <> NULL THEN
                Id := _input^.Id;
                Value := _input^.GetValue();
            END_IF;
        END_METHOD
    END_CLASS

END_NAMESPACE