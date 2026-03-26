NAMESPACE Esab.Utils.Filters

    INTERFACE IFilter
        /// Initializes the filter
        METHOD Initialize
        END_METHOD

        /// Adds a measurement to this filter.
        METHOD Measurement
            VAR_INPUT
                value : LREAL;
            END_VAR
        END_METHOD

        /// Returns the filtered value.
        METHOD Filtered : LREAL
        END_METHOD

        /// Sets the filter window size.
        /// The actual effect depends on the filter implementation.
        METHOD SetWindowSize
            VAR_INPUT
                size : INT;
            END_VAR
        END_METHOD

        /// Resets the filter to initial values.
        METHOD Reset
        END_METHOD
    END_INTERFACE

END_NAMESPACE