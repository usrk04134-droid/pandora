USING Siemens.Simatic.S71500.MotionControl;
USING Siemens.Simatic.S71500.MotionControl.Native;

NAMESPACE Esab.Motion

    CLASS TechnologyObjects
        VAR PRIVATE
            _horizontalSlideAxisDb : DB_ANY;
            _verticalSlideAxisDb : DB_ANY;

            _attached : BOOL := FALSE;
            _horizontalSlideAxisInstance : PosAxis;
            _verticalSlideAxisInstance : PosAxis;
        END_VAR

        METHOD PUBLIC Setup
            VAR_INPUT
                horizontalSlideAxisDb : DB_ANY;
                verticalSlideAxisDb : DB_ANY;
            END_VAR

            _horizontalSlideAxisDb := horizontalSlideAxisDb;
            _verticalSlideAxisDb := verticalSlideAxisDb;

            _attached :=  _horizontalSlideAxisInstance.Attach(_horizontalSlideAxisDb) AND _verticalSlideAxisInstance.Attach(_verticalSlideAxisDb);
        END_METHOD

        METHOD PUBLIC IsAttached : BOOL
            IsAttached := _attached;
        END_METHOD

        METHOD PUBLIC GetHorizontalSlideAxis : itfPosAxis
            GetHorizontalSlideAxis := _horizontalSlideAxisInstance;
        END_METHOD

        METHOD PUBLIC GetVerticalSlideAxis : itfPosAxis
            GetVerticalSlideAxis := _verticalSlideAxisInstance;
        END_METHOD
    END_CLASS

END_NAMESPACE