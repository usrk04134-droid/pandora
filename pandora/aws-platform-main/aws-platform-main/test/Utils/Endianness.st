USING AxUnit;

NAMESPACE Esab.Utils.Test

    {TestFixture}
    {Category(IO)}
    CLASS Endianness

        {Test}
        METHOD PUBLIC FlipInt
            Assert.Equal(Flip(TO_INT(WORD#16#020F)), WORD#16#0F02);
        END_METHOD

        {Test}
        METHOD PUBLIC FlipDInt
            Assert.Equal(Flip(TO_DINT(DWORD#16#010E020F)), DWORD#16#0F020E01);
        END_METHOD

        {Test}
        METHOD PUBLIC FlipUInt
            Assert.Equal(Flip(TO_UINT(WORD#16#020F)), WORD#16#0F02);
        END_METHOD

        {Test}
        METHOD PUBLIC FlipReal
            Assert.Equal(Flip(TO_REAL(DWORD#16#010E020F)), DWORD#16#0F020E01);
        END_METHOD

    END_CLASS

END_NAMESPACE