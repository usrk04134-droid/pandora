# Slice translator

```plantuml

    package calibration {
        interface "CalibrationSolver" as calibration::CalibrationSolver {
            + Calculate()
        }
        class "CalibrationSolverImpl" as calibration::CalibrationSolverImpl
        calibration::CalibrationSolverImpl -left-|> calibration::CalibrationSolver
        class "LwCalibrationHandler" as calibration::LwHandler
        class "CwCalibrationHandler" as calibration::CwHandler
    }

    package slice_translator {
        interface "RotationModelConfig" as slice_translator::RotationModelConfig {
            ----------
            Rotary configuration interface
            ----------
            + ActivateWithConfig(rotation params, transf)
        }
        interface "LinearModelConfig" as slice_translator::LinearModelConfig {
            ----------
            Linear configuration interface
            ----------
            + ActivateWithConfig(linear params, transf)
        }
        interface "OptimizableModel" as slice_translator::OptimizableModel {
            ----------
            Abstracts model behaviour needed for optimization of the model.
            (Replaces model_extract for more clear naming)
            ----------
            + StageConfig(rotation params)
            + TransformAndRotate(point)
        }
        interface "TranslationModel" as slice_translator::TranslationModel{
            ----------
            Common translation behaviour consumed by e.g. SliceTranslatorService
            ----------
            + LPCSToMCS
            + MCSToLPCS
            + DistanceFromTorchToScanner
            + Available
        }
        class "RotationModelImpl" as slice_translator::RotationModelImpl{
            -------
            Implements the coordination and configuration of transformer and trajectories
            for rotary weld motions.
            -------
            +ctor(ConfigurableCircleTrajectory, ConfigurableTransform, WeldMotionContext, ModelActivator)
        }

        class "LinearModelImpl" as slice_translator::LinearModelImpl {
            -------
            Implements the coordination and configuration of transformer and trajectories
            for linear weld motions.
            -------
            + ctor(ConfigurableLinearTrajectory, ConfigurableTransform, WeldMotionContext, ModelActivator)
        }
        interface "SliceTranslatorServiceV2" as slice_translator::SliceTranslator {
            -------
            Interface for clients that need to predict 
            weld motion and laser to torch geometry.
            -------
            + LPCSToMCS
            + MCSToLPCS
            + DistanceFromTorchToScanner
            + Available
        }
        interface "ModelActivator" as slice_translator::ModelActivator {
            ---------
            Interface to be used by clients that can 
            switch between CW and LW models
            ---------
            + SetActiveModel(TranslationModel)
        }
        class "SliceTranslatorServiceImpl" as slice_translator::SliceTranslatorServiceImpl {
            --------
            Wrapper/anonymizer for model implementations. Can switch model at runtime.
            --------
            active_model_ : TranslatorModel
        }

        slice_translator::SliceTranslatorServiceImpl -up-|> slice_translator::SliceTranslator
        slice_translator::SliceTranslatorServiceImpl -left-|> slice_translator::ModelActivator 

        slice_translator::RotationModelImpl -up-|> slice_translator::TranslationModel
        slice_translator::RotationModelImpl --|> slice_translator::OptimizableModel
        slice_translator::RotationModelImpl --|> slice_translator::RotationModelConfig
        slice_translator::RotationModelImpl --> slice_translator::ModelActivator 

        slice_translator::LinearModelImpl --|> slice_translator::LinearModelConfig
        slice_translator::LinearModelImpl -up-|> slice_translator::TranslationModel
        slice_translator::LinearModelImpl --> slice_translator::ModelActivator

        note as n1
            The slice translator models act as a facade in front of
            weld_motion_prediciton package.
        end note
        note as n2
            The slice translator service acts a model type anonymizer 
            for clients.
        end note
    }

    slice_translator::SliceTranslator .. n2
    slice_translator::RotationModelImpl .up. n1
       
    class "ClientEntity"
    ClientEntity --> slice_translator::SliceTranslator
    
    calibration::CwHandler -right-> calibration::CalibrationSolver : Calculate()
    calibration::LwHandler -up-> slice_translator::LinearModelConfig
    calibration::CwHandler -up-> slice_translator::RotationModelConfig
    calibration::CalibrationSolverImpl -right-> slice_translator::OptimizableModel
    slice_translator::SliceTranslatorServiceImpl --> slice_translator::TranslationModel

```
