# Slice translator/weld motion prediciton

```plantuml

    package weld_motion_prediction {
        interface "WeldMotionContext" as weld_motion_prediction::WeldMotionContext{
            -------
            Abstracts motion prediction and transformation \nindependent of motion type
            -------
            + torch_plane_ : Plane3d 
            + laser_plane_ : Plane3d 
            + IntersectTorchPlane(lpcs::Point, ITrajectory) : common::Point
            + IntersectLaserPlane(common::Point, ITrajectory) : lpcs::Point
            + SetActiveTrajectory(ITrajectory)
        }
        
        interface "ConfigurableLinearTrajectory" as weld_motion_prediction::ConfigurableLinearTrajectory{
            --------
            Abstracts configuration that is specific to linear motion            
            --------
            + Set(linear params)
        }
        interface "ConfigurableCircleTrajectory" as weld_motion_prediction::ConfigurableCircleTrajectory{
            --------
            Abstracts configuration that is specific to rotary motion
            --------
            + Set(rotation params)
        }
        interface "ITransformer" as weld_motion_prediction::ITransformer {
            ---------
            Abstracts pure coordinate transformation
            ---------
            + LpcsToMacs()
            + MacsToLPCS()
        }
        interface "ConfigurableTransform" as weld_motion_prediction::ConfigurableTransform{
            ---------
            Abstracts the configuration of transformations.
            Basically taking the results of LTC
            ---------
            + SetTransform(rotation, translation)
        }
        class "LinearTrajectory" as weld_motion_prediction::LinearTrajectory
        class "CircleTrajectory" as weld_motion_prediction::CircleTrajectory
        class "WeldMotionContextImpl" as weld_motion_prediction::WeldMotionContextImpl {
            + ctor(ITrajectory, ITransformer)
        }
        class "CoordinateTransformer" as weld_motion_prediction::CoordinateTransformer {

        }
        interface "ITrajectory" as weld_motion_prediction::ITrajectory {
            --------
            Abstracts motion prediction 
            --------
            + Intersect(Plane3d)
            + AttachToPoint(Point3d)
        }        

        weld_motion_prediction::CoordinateTransformer --|> weld_motion_prediction::ITransformer
        weld_motion_prediction::CoordinateTransformer --|> weld_motion_prediction::ConfigurableTransform
        weld_motion_prediction::WeldMotionContextImpl -up-|> weld_motion_prediction::WeldMotionContext        
        weld_motion_prediction::LinearTrajectory -up-|> weld_motion_prediction::ConfigurableLinearTrajectory
        weld_motion_prediction::CircleTrajectory -up-|> weld_motion_prediction::ConfigurableCircleTrajectory
        weld_motion_prediction::ConfigurableLinearTrajectory -up-|> weld_motion_prediction::ITrajectory
        weld_motion_prediction::ConfigurableCircleTrajectory -up-|> weld_motion_prediction::ITrajectory
    }

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
            + ActivateWithConfig(rotation params, transf)
        }
        interface "LinearModelConfig" as slice_translator::LinearModelConfig {
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
            Wrapper for model implementations. Can switch model at runtime.
            --------
            active_model_ : TranslatorModel
        }

        slice_translator::SliceTranslatorServiceImpl --|> slice_translator::SliceTranslator
        slice_translator::SliceTranslatorServiceImpl --|> slice_translator::ModelActivator 

        slice_translator::RotationModelImpl -down-|> slice_translator::TranslationModel
        slice_translator::RotationModelImpl --|> slice_translator::OptimizableModel
        slice_translator::RotationModelImpl --|> slice_translator::RotationModelConfig

        slice_translator::LinearModelImpl --|> slice_translator::LinearModelConfig
        slice_translator::LinearModelImpl -down-|> slice_translator::TranslationModel
    }

    class "ClientEntity"
    ClientEntity --> slice_translator::SliceTranslator
    
    calibration::CwHandler -right-> calibration::CalibrationSolver : Calculate()
    calibration::LwHandler -up-> slice_translator::LinearModelConfig
    calibration::CwHandler -up-> slice_translator::RotationModelConfig
    calibration::CalibrationSolverImpl -right-> slice_translator::OptimizableModel

    slice_translator::RotationModelImpl --> weld_motion_prediction::ConfigurableCircleTrajectory
    slice_translator::LinearModelImpl --> weld_motion_prediction::ConfigurableLinearTrajectory

    slice_translator::RotationModelImpl -up-> weld_motion_prediction::WeldMotionContext
    slice_translator::LinearModelImpl -up-> weld_motion_prediction::WeldMotionContext

    slice_translator::LinearModelImpl --> weld_motion_prediction::ConfigurableTransform
    slice_translator::RotationModelImpl --> weld_motion_prediction::ConfigurableTransform
    slice_translator::LinearModelImpl --> slice_translator::ModelActivator

    weld_motion_prediction::WeldMotionContextImpl --> weld_motion_prediction::ITrajectory
    weld_motion_prediction::WeldMotionContextImpl -left-> weld_motion_prediction::ITransformer

    slice_translator::SliceTranslatorServiceImpl --> slice_translator::TranslationModel

```
