# Weld motion prediction

```plantuml

    package weld_motion_prediction {
        interface "WeldMotionContext" as weld_motion_prediction::WeldMotionContext{
            -------
            Abstracts motion prediction and transformation \nindependent of motion type
            Comsumed by slice_translator linear/rotary models
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
            Consumed by slice_translator linear model
            --------
            + Set(linear params)
        }
        interface "ConfigurableCircleTrajectory" as weld_motion_prediction::ConfigurableCircleTrajectory{
            --------
            Abstracts configuration that is specific to rotary motion
            Consumed by slice_translator rotary model
            --------
            + Set(rotation params)
        }
        interface "ConfigurableTransform" as weld_motion_prediction::ConfigurableTransform{
            ---------
            Abstracts the configuration of transformations.
            Consumed by slice_translator linear/rotary models
            ---------
            + SetTransform(rotation, translation)
        }
        interface "ITransformer" as weld_motion_prediction::ITransformer {
            ---------
            Abstracts pure coordinate transformation
            ---------
            + LpcsToMacs()
            + MacsToLPCS()
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

        weld_motion_prediction::CoordinateTransformer -up-|> weld_motion_prediction::ConfigurableTransform
        weld_motion_prediction::CoordinateTransformer -up-|> weld_motion_prediction::ITransformer
        weld_motion_prediction::WeldMotionContextImpl -right-|> weld_motion_prediction::WeldMotionContext        
        weld_motion_prediction::LinearTrajectory -up-|> weld_motion_prediction::ConfigurableLinearTrajectory
        weld_motion_prediction::CircleTrajectory -up-|> weld_motion_prediction::ConfigurableCircleTrajectory
        weld_motion_prediction::ConfigurableLinearTrajectory -up-|> weld_motion_prediction::ITrajectory
        weld_motion_prediction::ConfigurableCircleTrajectory -up-|> weld_motion_prediction::ITrajectory

    }

    note as n1
        Motion strategy implementations
    end note
    note as n2
        Context for strategy selection and execution
    end note

    weld_motion_prediction::WeldMotionContext .. n2
    weld_motion_prediction::LinearTrajectory .. n1
    weld_motion_prediction::CircleTrajectory .. n1

    weld_motion_prediction::WeldMotionContextImpl --> weld_motion_prediction::ITrajectory
    weld_motion_prediction::WeldMotionContextImpl -left-> weld_motion_prediction::ITransformer

```
