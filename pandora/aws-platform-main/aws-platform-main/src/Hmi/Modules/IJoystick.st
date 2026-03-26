NAMESPACE Esab.Hmi.Modules

    INTERFACE IJoystick
        /// Cyclic execute
        METHOD Execute
        END_METHOD

        /// Returns the current direction (position) of the joystick
        METHOD GetPosition : JoystickPosition
        END_METHOD

        /// Sets the click listener
        METHOD SetClickListener
            VAR_INPUT
                listener : IClickListener;
            END_VAR
        END_METHOD

        /// Sets the long hold listener
        METHOD SetLongHoldListener
            VAR_INPUT
                listener : ILongHoldListener;
            END_VAR
        END_METHOD

        /// Sets the position changed listener
        METHOD SetPositionChangedListener
            VAR_INPUT
                listener : IPositionChangedListener;
            END_VAR
        END_METHOD
    END_INTERFACE

    INTERFACE IClickListener
        /// Called when the joystick is clicked
        METHOD OnClick
            VAR_INPUT
                direction : JoystickPosition;
            END_VAR
        END_METHOD
    END_INTERFACE

    INTERFACE ILongHoldListener
        /// Called when long hold is first detected
        METHOD OnLongHoldDetected
            VAR_INPUT
                direction : JoystickPosition;
            END_VAR
        END_METHOD

        /// Called every execution cycle until release
        METHOD OnLongHold
            VAR_INPUT
                direction : JoystickPosition;
            END_VAR
        END_METHOD

        /// Called when the joystick is released after a long hold
        /// The direction will be the direction the joystick was held in before release
        METHOD OnLongHoldReleased
            VAR_INPUT
                direction : JoystickPosition;
            END_VAR
        END_METHOD
    END_INTERFACE

    INTERFACE IPositionChangedListener
        /// Called when the joysticks direction changes
        METHOD OnPositionChanged
            VAR_INPUT
                position : JoystickPosition;
            END_VAR
        END_METHOD
    END_INTERFACE

    TYPE
        JoystickPosition : INT(None := -1,
                               Center := 0,
                               Up := 1,
                               Down := 2,
                               Triangle := 3,
                               Square := 4
                           ) := Center;
    END_TYPE

END_NAMESPACE