
NAMESPACE Esab.Utils.Heartbeat

    /// Defines an interface for a heartbeat implementation
    INTERFACE IHeartbeat
        /// Cyclic execution to evaluate heartbeat
        METHOD Execute
        END_METHOD

        /// Returns TRUE if a heartbeat is detected
        METHOD Alive : BOOL
        END_METHOD

        /// Returns TRUE if no heartbeat is detected
        METHOD Dead : BOOL
        END_METHOD
    END_INTERFACE

END_NAMESPACE