USING Esab.Io.Mock;

USING AxUnit;

NAMESPACE Esab.Io.Test

    {TestFixture}
    {Category(IO)}
    CLASS DigitalInputTests
        VAR PRIVATE
            _value : BOOL;
            _input : DigitalInput;
            _changedHandler : DigitalInputChangedListenerMock;
        END_VAR

        {FixtureSetup}
        METHOD PUBLIC TestFixtureSetup
            ;
        END_METHOD

        {TestSetup}
        METHOD PUBLIC TestSetup
            _changedHandler.Id := UINT#0;
            _changedHandler.Value := FALSE;
            // Read two times to reset state.
            _input.Id := UINT#0;
            _input.Read(FALSE);
            _input.Read(FALSE);
        END_METHOD

        {Test}
        METHOD PUBLIC GetValue
            _input.Read(TRUE);
            Assert.Equal(_input.GetValue(), TRUE);
            _input.Read(FALSE);
            Assert.Equal(_input.GetValue(), FALSE);
        END_METHOD

        {Test}
        METHOD PUBLIC RisingEdge
            _input.Read(TRUE);
            Assert.Equal(_input.GetValue(), TRUE);
            Assert.Equal(_input.RisingEdge(), TRUE);
            Assert.Equal(_input.FallingEdge(), FALSE);
            _input.Read(TRUE);
            Assert.Equal(_input.GetValue(), TRUE);
            Assert.Equal(_input.RisingEdge(), FALSE);
            Assert.Equal(_input.FallingEdge(), FALSE);
        END_METHOD

        {Test}
        METHOD PUBLIC FallingEdge
            _input.Read(TRUE);
            Assert.Equal(_input.GetValue(), TRUE);
            _input.Read(FALSE);
            Assert.Equal(_input.GetValue(), FALSE);
            Assert.Equal(_input.RisingEdge(), FALSE);
            Assert.Equal(_input.FallingEdge(), TRUE);
            _input.Read(FALSE);
            Assert.Equal(_input.GetValue(), FALSE);
            Assert.Equal(_input.RisingEdge(), FALSE);
            Assert.Equal(_input.FallingEdge(), FALSE);
        END_METHOD

        {Test}
        METHOD PUBLIC OnChangedRising
            _input.Id := UINT#255;
            _input.SetChangedHandler(_changedHandler);

            _input.Read(FALSE);
            _input.Read(TRUE);

            Assert.Equal(_input.GetValue(), TRUE);
            Assert.Equal(_changedHandler.Id, UINT#255);
            Assert.Equal(_changedHandler.Value, TRUE);
        END_METHOD

        {Test}
        METHOD PUBLIC OnChangedFalling
            _input.Id := UINT#255;
            _input.SetChangedHandler(_changedHandler);

            _input.Read(FALSE);
            _input.Read(TRUE);
            _input.Read(FALSE);

            Assert.Equal(_input.GetValue(), FALSE);
            Assert.Equal(_changedHandler.Id, UINT#255);
            Assert.Equal(_changedHandler.Value, FALSE);
        END_METHOD

        {Test}
        METHOD PUBLIC HasChanged
            _input.Read(TRUE);
            _input.Read(TRUE);
            Assert.Equal(_input.HasChanged(), FALSE);
            _input.Read(FALSE);
            Assert.Equal(_input.HasChanged(), TRUE);
            _input.Read(TRUE);
            Assert.Equal(_input.HasChanged(), TRUE);
        END_METHOD
    END_CLASS

    {TestFixture}
    CLASS DigitalOutputTests
        VAR PRIVATE
            _outputValue : BOOL;
            _output : DigitalOutput;
        END_VAR

        {FixtureSetup}
        METHOD PUBLIC TestFixtureSetup
            ;
        END_METHOD

        {TestSetup}
        METHOD PUBLIC TestSetup
            _outputValue := FALSE;
            _output.SetValue(_outputValue);
        END_METHOD

        {Test}
        METHOD PUBLIC Set
            _output.Set();
            _output.Write(value => _outputValue);

            Assert.Equal(_outputValue, TRUE);
        END_METHOD

        {Test}
        METHOD PUBLIC Reset
            _outputValue := TRUE;
            _output.Reset();
            _output.Write(value => _outputValue);

            Assert.Equal(_outputValue, FALSE);
        END_METHOD

        {Test}
        METHOD PUBLIC Toggle
            _output.Toggle();
            _output.Write(value => _outputValue);

            Assert.Equal(_outputValue, TRUE);

            _output.Toggle();
            _output.Write(value => _outputValue);

            Assert.Equal(_outputValue, FALSE);
        END_METHOD

        {Test}
        METHOD PUBLIC ToggleRepeatedly
            _output.Toggle();
            _output.Toggle();
            _output.Toggle();
            _output.Toggle();
            _output.Toggle();
            _output.Write(value => _outputValue);

            Assert.Equal(_outputValue, TRUE);
            _output.Toggle();
            _output.Toggle();
            _output.Toggle();
            _output.Toggle();
            _output.Toggle();
            _output.Write(value => _outputValue);

            Assert.Equal(_outputValue, FALSE);
        END_METHOD

        {Test}
        METHOD PUBLIC SetValue
            _output.SetValue(TRUE);
            _output.Write(value => _outputValue);

            Assert.Equal(_outputValue, TRUE);

            _output.SetValue(FALSE);
            _output.Write(value => _outputValue);

            Assert.Equal(_outputValue, FALSE);
        END_METHOD
    END_CLASS

    CLASS DigitalInputChangedListenerMock IMPLEMENTS InputChangedListener
        VAR PUBLIC
            Id : UINT;
            Value : BOOL;
        END_VAR

        METHOD PUBLIC InputChanged
            VAR_INPUT
                input : REF_TO Input;
            END_VAR

            VAR_TEMP
                _input : REF_TO DigitalInput;
            END_VAR

            _input ?= input;

            IF _input <> NULL THEN
                Id := _input^.Id;
                Value := _input^.GetValue();
            END_IF;
        END_METHOD
    END_CLASS

END_NAMESPACE