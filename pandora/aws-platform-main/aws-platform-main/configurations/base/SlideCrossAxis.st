USING Esab.Motion;
USING Esab.Utils.Assets;

CONFIGURATION SlideCrossConfiguration
    // Constants
    VAR_GLOBAL CONSTANT
        HORIZONTAL_SLIDE_AXIS_DB : Siemens.Simatic.S71500.MotionControl.Native.DB_ANY := UINT#1;
        VERTICAL_SLIDE_AXIS_DB : Siemens.Simatic.S71500.MotionControl.Native.DB_ANY := UINT#2;
    END_VAR

    // Objects
    VAR_GLOBAL
        Technology : TechnologyObjects;
        HorizontalSlideAxis : ToPosAxis;
        HorizontalSlideAxisRuntimeParameters : AxisRuntimeParameters;
        VerticalSlideAxis : ToPosAxis;
        VerticalSlideAxisRuntimeParameters : AxisRuntimeParameters;
    END_VAR

    // Alarms
    VAR_GLOBAL
    END_VAR

    // Interface
    VAR_GLOBAL
    END_VAR
END_CONFIGURATION

FUNCTION InitializeSlideCrossAxis
    VAR_INPUT
        assetsManager : IAssetsManager;
    END_VAR

    VAR_EXTERNAL CONSTANT
        HORIZONTAL_SLIDE_AXIS_DB : Siemens.Simatic.S71500.MotionControl.Native.DB_ANY;
        VERTICAL_SLIDE_AXIS_DB : Siemens.Simatic.S71500.MotionControl.Native.DB_ANY;
    END_VAR

    VAR_EXTERNAL
        Technology : TechnologyObjects;
        HorizontalSlideAxis : ToPosAxis;
        HorizontalSlideAxisRuntimeParameters : AxisRuntimeParameters;
        VerticalSlideAxis : ToPosAxis;
        VerticalSlideAxisRuntimeParameters : AxisRuntimeParameters;
    END_VAR

    Technology.Setup(HORIZONTAL_SLIDE_AXIS_DB, VERTICAL_SLIDE_AXIS_DB);

    IF Technology.IsAttached() THEN
        HorizontalSlideAxis.Setup(Technology.GetHorizontalSlideAxis(), REF(HorizontalSlideAxisRuntimeParameters));
        VerticalSlideAxis.Setup(Technology.GetVerticalSlideAxis(), REF(VerticalSlideAxisRuntimeParameters));

        HorizontalSlideAxis.SetIdentifier(Esab.AssetIdentifier#HorizontalSlideAxis);
        VerticalSlideAxis.SetIdentifier(Esab.AssetIdentifier#VerticalSlideAxis);
        assetsManager.RegisterAsset(REF(HorizontalSlideAxis));
        assetsManager.RegisterAsset(REF(VerticalSlideAxis));
    END_IF;
END_FUNCTION