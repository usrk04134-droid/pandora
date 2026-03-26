USING Esab.Mock;

USING Esab.Io.Mock;
USING Esab.Utils.Timer.Mock;

USING AxUnit;

NAMESPACE Esab.Hmi.Modules.Test

    {TestFixture}
    {Category(DiscreteJoystick)}
    CLASS DiscreteJoystickTests
        VAR PRIVATE
            _timer : OnDelayMock;
            _joystick : DiscreteJoystick;
            _joystickIo : DiscreteJoystickIo;
            _clickListener : DiscreteJoystick.ClickListenerMock;
            _longHoldListener : DiscreteJoystick.LongHoldListenerMock;
            _positionChangedListener : DiscreteJoystick.PositionChangedListenerMock;
        END_VAR

        {FixtureSetup}
        METHOD PUBLIC TestFixtureSetup
            _joystick.Setup(REF(_joystickIo), _timer);
        END_METHOD

        {TestSetup}
        METHOD PUBLIC TestSetup
            // Clear data (twice for each to clear falling/rising)
            _joystickIo.Up.Read(FALSE);
            _joystickIo.Up.Read(FALSE);
            _joystickIo.Down.Read(FALSE);
            _joystickIo.Down.Read(FALSE);
            _joystickIo.Triangle.Read(FALSE);
            _joystickIo.Triangle.Read(FALSE);
            _joystickIo.Square.Read(FALSE);
            _joystickIo.Square.Read(FALSE);

            _timer.MockReset();
            _clickListener.MockReset();
            _longHoldListener.MockReset();
            _positionChangedListener.MockReset();

            _joystick.Execute();
            _joystick.Execute();
            _joystick.Execute();
        END_METHOD

        {Test(position := 0)}
        {Test(position := 1)}
        {Test(position := 2)}
        {Test(position := 3)}
        {Test(position := 4)}
        METHOD PUBLIC TestGetPosition
            VAR_INPUT
                position : INT;
            END_VAR

            VAR_TEMP
                joystickPosition : JoystickPosition;
            END_VAR

            joystickPosition := position;

            CASE joystickPosition OF
                JoystickPosition#Center:
                    ;
                JoystickPosition#Up:
                    _joystickIo.Up.Read(TRUE);
                JoystickPosition#Down:
                    _joystickIo.Down.Read(TRUE);
                JoystickPosition#Triangle:
                    _joystickIo.Triangle.Read(TRUE);
                JoystickPosition#Square:
                    _joystickIo.Square.Read(TRUE);
            END_CASE;

            _joystick.Execute();

            Assert.Equal(_joystick.GetPosition(), joystickPosition);
        END_METHOD

        {Test(position := 1)}
        {Test(position := 2)}
        {Test(position := 3)}
        {Test(position := 4)}
        METHOD PUBLIC TestClickCallback
            VAR_INPUT
                position : INT;
            END_VAR

            VAR_TEMP
                joystickPosition : JoystickPosition;
            END_VAR

            joystickPosition := position;

            _joystick.SetClickListener(_clickListener);

            CASE joystickPosition OF
                JoystickPosition#Center:
                    ;
                JoystickPosition#Up:
                    _joystickIo.Up.Read(TRUE);
                JoystickPosition#Down:
                    _joystickIo.Down.Read(TRUE);
                JoystickPosition#Triangle:
                    _joystickIo.Triangle.Read(TRUE);
                JoystickPosition#Square:
                    _joystickIo.Square.Read(TRUE);
            END_CASE;

            _joystick.Execute();
            _joystick.Execute();
            _joystick.Execute();

            _joystickIo.Up.Read(FALSE);
            _joystickIo.Down.Read(FALSE);
            _joystickIo.Triangle.Read(FALSE);
            _joystickIo.Square.Read(FALSE);

            _joystick.Execute();
            _joystick.Execute();
            _joystick.Execute();

            Assert.Equal(_joystick.GetPosition(), JoystickPosition#Center);
            Assert.Equal(_clickListener.OnClickMock.GetCallCount(), UINT#1);
            Assert.Equal(_clickListener.OnClickMock.Direction, joystickPosition);
        END_METHOD

        {Test(position := 1)}
        {Test(position := 2)}
        {Test(position := 3)}
        {Test(position := 4)}
        METHOD PUBLIC TestLongHoldCallback
            VAR_INPUT
                position : INT;
            END_VAR

            VAR_TEMP
                joystickPosition : JoystickPosition;
            END_VAR

            joystickPosition := position;

            _joystick.SetLongHoldListener(_longHoldListener);

            CASE joystickPosition OF
                JoystickPosition#Center:
                    ;
                JoystickPosition#Up:
                    _joystickIo.Up.Read(TRUE);
                JoystickPosition#Down:
                    _joystickIo.Down.Read(TRUE);
                JoystickPosition#Triangle:
                    _joystickIo.Triangle.Read(TRUE);
                JoystickPosition#Square:
                    _joystickIo.Square.Read(TRUE);
            END_CASE;

            _joystick.Execute();

            _timer.ExpiredMock.Value := TRUE;

            _joystick.Execute();

            Assert.Equal(_longHoldListener.OnLongHoldInitiatedMock.GetCallCount(), UINT#1);
            Assert.Equal(_longHoldListener.OnLongHoldMock.GetCallCount(), UINT#0);
            Assert.Equal(_longHoldListener.OnLongHoldReleasedMock.GetCallCount(), UINT#0);
            Assert.Equal(_longHoldListener.OnLongHoldInitiatedMock.Direction, joystickPosition);

            _joystick.Execute();
            _joystick.Execute();
            _joystick.Execute();

            Assert.Equal(_longHoldListener.OnLongHoldInitiatedMock.GetCallCount(), UINT#1);
            Assert.Equal(_longHoldListener.OnLongHoldMock.GetCallCount(), UINT#3);
            Assert.Equal(_longHoldListener.OnLongHoldReleasedMock.GetCallCount(), UINT#0);
            Assert.Equal(_longHoldListener.OnLongHoldMock.Direction, joystickPosition);

            _joystick.Execute();
            _joystick.Execute();

            _timer.ExpiredMock.Value := FALSE;

            _joystick.Execute();

            Assert.Equal(_longHoldListener.OnLongHoldInitiatedMock.GetCallCount(), UINT#1);
            Assert.Equal(_longHoldListener.OnLongHoldMock.GetCallCount(), UINT#5);
            Assert.Equal(_longHoldListener.OnLongHoldReleasedMock.GetCallCount(), UINT#1);
            Assert.Equal(_longHoldListener.OnLongHoldReleasedMock.Direction, joystickPosition);
        END_METHOD

        {Test(position := 1)}
        {Test(position := 2)}
        {Test(position := 3)}
        {Test(position := 4)}
        METHOD PUBLIC TestPositionChangedCallback
            VAR_INPUT
                position : INT;
            END_VAR

            VAR_TEMP
                joystickPosition : JoystickPosition;
            END_VAR

            joystickPosition := position;

            _joystick.SetPositionChangedListener(_positionChangedListener);

            CASE joystickPosition OF
                JoystickPosition#Center:
                    ;
                JoystickPosition#Up:
                    _joystickIo.Up.Read(TRUE);
                JoystickPosition#Down:
                    _joystickIo.Down.Read(TRUE);
                JoystickPosition#Triangle:
                    _joystickIo.Triangle.Read(TRUE);
                JoystickPosition#Square:
                    _joystickIo.Square.Read(TRUE);
            END_CASE;

            _joystick.Execute();
            _joystick.Execute();
            _joystick.Execute();
            _joystick.Execute();

            Assert.Equal(_positionChangedListener.OnPositionChangedMock.GetCallCount(), UINT#1);
            Assert.Equal(_positionChangedListener.OnPositionChangedMock.Position, joystickPosition);

            _joystickIo.Up.Read(FALSE);
            _joystickIo.Down.Read(FALSE);
            _joystickIo.Triangle.Read(FALSE);
            _joystickIo.Square.Read(FALSE);

            _joystick.Execute();
            _joystick.Execute();
            _joystick.Execute();
            _joystick.Execute();

            Assert.Equal(_positionChangedListener.OnPositionChangedMock.GetCallCount(), UINT#2);
            Assert.Equal(_positionChangedListener.OnPositionChangedMock.Position, JoystickPosition#Center);
        END_METHOD
    END_CLASS

    NAMESPACE DiscreteJoystick
        CLASS ClickListenerMock IMPLEMENTS IClickListener
            VAR PUBLIC
                OnClickMock : OnClickMock;
            END_VAR

            METHOD PUBLIC MockReset
                OnClickMock.Reset();
            END_METHOD

            METHOD PUBLIC OnClick
                VAR_INPUT
                    direction : JoystickPosition;
                END_VAR

                OnClickMock.IncrementCallCount();
                OnClickMock.Direction := direction;
            END_METHOD
        END_CLASS

        CLASS OnClickMock EXTENDS MethodMock
            VAR PUBLIC
                Direction : JoystickPosition;
            END_VAR

            METHOD PUBLIC OVERRIDE Reset
                Direction := JoystickPosition#Center;
                SUPER.Reset();
            END_METHOD
        END_CLASS

        CLASS LongHoldListenerMock IMPLEMENTS ILongHoldListener
            VAR PUBLIC
                OnLongHoldInitiatedMock : JoystickPositionMock;
                OnLongHoldMock : JoystickPositionMock;
                OnLongHoldReleasedMock : JoystickPositionMock;
            END_VAR

            METHOD PUBLIC MockReset
                OnLongHoldInitiatedMock.Reset();
                OnLongHoldMock.Reset();
                OnLongHoldReleasedMock.Reset();
            END_METHOD

            METHOD PUBLIC OnLongHoldDetected
                VAR_INPUT
                    direction : JoystickPosition;
                END_VAR

                OnLongHoldInitiatedMock.IncrementCallCount();
                OnLongHoldInitiatedMock.Direction := direction;
            END_METHOD

            METHOD PUBLIC OnLongHold
                VAR_INPUT
                    direction : JoystickPosition;
                END_VAR

                OnLongHoldMock.IncrementCallCount();
                OnLongHoldMock.Direction := direction;
            END_METHOD

            METHOD PUBLIC OnLongHoldReleased
                VAR_INPUT
                    direction : JoystickPosition;
                END_VAR

                OnLongHoldReleasedMock.IncrementCallCount();
                OnLongHoldReleasedMock.Direction := direction;
            END_METHOD
        END_CLASS

        CLASS JoystickPositionMock EXTENDS MethodMock
            VAR PUBLIC
                Direction : JoystickPosition;
            END_VAR

            METHOD PUBLIC OVERRIDE Reset
                Direction := JoystickPosition#Center;
                SUPER.Reset();
            END_METHOD
        END_CLASS

        CLASS PositionChangedListenerMock IMPLEMENTS IPositionChangedListener
            VAR PUBLIC
                OnPositionChangedMock : OnPositionChangedMock;
            END_VAR

            METHOD PUBLIC MockReset
                OnPositionChangedMock.Reset();
            END_METHOD

            METHOD PUBLIC OnPositionChanged
                VAR_INPUT
                    position : JoystickPosition;
                END_VAR

                OnPositionChangedMock.IncrementCallCount();
                OnPositionChangedMock.Position := position;
            END_METHOD
        END_CLASS

        CLASS OnPositionChangedMock EXTENDS MethodMock
            VAR PUBLIC
                Position : JoystickPosition;
            END_VAR

            METHOD PUBLIC OVERRIDE Reset
                Position := JoystickPosition#Center;
                SUPER.Reset();
            END_METHOD
        END_CLASS
    END_NAMESPACE

END_NAMESPACE