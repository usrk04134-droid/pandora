USING Esab.Mock;
USING Esab.Mock;
USING Esab.Mock;
USING AxUnit;

NAMESPACE Esab.Utils.Collections.Test

    {TestFixture}
    {Category(Collections)}
    CLASS LinkedListTests

        VAR PRIVATE
            _list : LinkedList;
            _emptyList : LinkedList;
            _item1 : TestItem;
            _item2 : TestItem;
            _item3 : TestItem;
            _item4 : TestItem;
            _intItem1 : TestIntItem;
            _intItem2 : TestIntItem;
            _intItem3 : TestIntItem;
            _intItem4 : TestIntItem;
            _comparator : ComparatorMock;
            _addOperation : AddOperation;
        END_VAR

        {FixtureSetup}
        METHOD PUBLIC TestFixtureSetup
            ;
        END_METHOD

        {TestSetup}
        METHOD PUBLIC TestSetup
            _list := _emptyList;
            _item1.SetNext(NULL);
            _item2.SetNext(NULL);
            _item3.SetNext(NULL);
            _item4.SetNext(NULL);
            _comparator.MockReset();
        END_METHOD

        {Test}
        METHOD PUBLIC Append
            VAR_TEMP
                head : REF_TO TestItem;
            END_VAR

            _list.Append(REF(_item1));
            _list.Append(REF(_item2));
            _list.Append(REF(_item3));

            Assert.Equal(_item1.GetNext() = REF(_item2), TRUE);
            Assert.Equal(_item2.GetNext() = REF(_item3), TRUE);
            Assert.Equal(_item3.GetNext() = NULL, TRUE);

            head ?= _list.PopHead();
            Assert.Equal(head = REF(_item1), TRUE);
            head ?= _list.PopHead();
            Assert.Equal(head = REF(_item2), TRUE);
            head ?= _list.PopHead();
            Assert.Equal(head = REF(_item3), TRUE);
        END_METHOD

        {Test}
        METHOD PUBLIC Prepend
            VAR_TEMP
                head : REF_TO TestItem;
            END_VAR

            _list.Prepend(REF(_item1));
            _list.Prepend(REF(_item2));
            _list.Prepend(REF(_item3));

            Assert.Equal(_item1.GetNext() = NULL, TRUE);
            Assert.Equal(_item2.GetNext() = REF(_item1), TRUE);
            Assert.Equal(_item3.GetNext() = REF(_item2), TRUE);

            head ?= _list.PopHead();
            Assert.Equal(head = REF(_item3), TRUE);
            head ?= _list.PopHead();
            Assert.Equal(head = REF(_item2), TRUE);
            head ?= _list.PopHead();
            Assert.Equal(head = REF(_item1), TRUE);
        END_METHOD

        {Test}
        METHOD PUBLIC Size
            _list.Append(REF(_item1));
            _list.Append(REF(_item2));
            _list.Append(REF(_item3));
            _list.Append(REF(_item4));

            Assert.Equal(_list.Size(), 4);

            _list.PopHead();
            _list.PopHead();

            Assert.Equal(_list.Size(), 2);
        END_METHOD

        {Test}
        METHOD PUBLIC PopHead
            VAR_TEMP
                head : REF_TO TestItem;
            END_VAR

            _list.Append(REF(_item1));
            head ?= _list.PopHead();
            Assert.Equal(head = REF(_item1), TRUE);

            head ?= _list.PopHead();
            Assert.Equal(head = NULL, TRUE);
        END_METHOD

        {Test}
        METHOD PUBLIC Clear
            _list.Append(REF(_item1));
            _list.Append(REF(_item2));
            _list.Append(REF(_item3));
            _list.Append(REF(_item4));

            _list.Clear();

            Assert.Equal(_item1.GetNext() = NULL, TRUE);
            Assert.Equal(_item2.GetNext() = NULL, TRUE);
            Assert.Equal(_item3.GetNext() = NULL, TRUE);
            Assert.Equal(_item4.GetNext() = NULL, TRUE);
            Assert.Equal(_list.Size(), 0);
        END_METHOD

        {Test}
        METHOD PUBLIC ClearCircularList
            _list.Append(REF(_item1));
            _list.Append(REF(_item2));
            _list.Append(REF(_item3));
            _list.Append(REF(_item4));

            _item4.SetNext(REF(_item1));

            _list.Clear();

            Assert.Equal(_item1.GetNext() = NULL, TRUE);
            Assert.Equal(_item2.GetNext() = NULL, TRUE);
            Assert.Equal(_item3.GetNext() = NULL, TRUE);
            Assert.Equal(_item4.GetNext() = NULL, TRUE);
            Assert.Equal(_list.Size(), 0);
        END_METHOD

        {Test}
        METHOD PUBLIC Empty
            _list.Append(REF(_item1));
            _list.Append(REF(_item2));
            _list.Append(REF(_item3));
            _list.Append(REF(_item4));
            Assert.Equal(_list.Empty(), FALSE);

            _list.Clear();
            Assert.Equal(_list.Empty(), TRUE);
        END_METHOD

        {Test}
        METHOD PUBLIC PushAfterPopEmpty
            VAR_TEMP
                head : REF_TO TestItem;
            END_VAR

            _list.Append(REF(_item1));
            _list.Append(REF(_item2));
            Assert.Equal(_list.Size(), 2);
            _list.PopHead();
            _list.PopHead();
            Assert.Equal(_list.Size(), 0);
            _list.Append(REF(_item1));
            _list.Append(REF(_item2));

            head ?= _list.PopHead();
            Assert.Equal(head = REF(_item1), TRUE);
            head ?= _list.PopHead();
            Assert.Equal(head = REF(_item2), TRUE);
        END_METHOD

        {Test}
        METHOD PUBLIC AddItemMultipleTimes
            _list.Append(REF(_item1));

            _list.Append(REF(_item1));
            _list.Append(REF(_item1));
            _list.Append(REF(_item1));
            _list.Append(REF(_item1));

            _list.Prepend(REF(_item1));
            _list.Prepend(REF(_item1));
            _list.Prepend(REF(_item1));
            _list.Prepend(REF(_item1));

            Assert.Equal(_list.Size(), 1);
        END_METHOD

        {Test}
        METHOD PUBLIC SearchMatch
            VAR_TEMP
                _item : REF_TO TestItem;
            END_VAR

            _list.Append(REF(_item1));
            _list.Append(REF(_item2));
            _list.Append(REF(_item3));
            _list.Append(REF(_item4));

            _comparator.CompareMock.Value := 0;
            _item ?= _list.Find(_comparator);
            Assert.Equal(_item = REF(_item1), TRUE);
            Assert.Equal(_comparator.CompareMock.GetCallCount(), UINT#1);
            Assert.Equal(_comparator.CompareMock.Item = REF(_item1), TRUE);
        END_METHOD

        {Test}
        METHOD PUBLIC SearchNoMatch
            VAR_TEMP
                _item : REF_TO TestItem;
            END_VAR

            _list.Append(REF(_item1));
            _list.Append(REF(_item2));
            _list.Append(REF(_item3));
            _list.Append(REF(_item4));

            _comparator.CompareMock.Value := -1;
            _item ?= _list.Find(_comparator);
            Assert.Equal(_item = NULL, TRUE);
            Assert.Equal(_comparator.CompareMock.GetCallCount(), UINT#4);
            Assert.Equal(_comparator.CompareMock.Item = REF(_item4), TRUE);
        END_METHOD

        {Test}
        METHOD PUBLIC Operation
            _intItem1.Value := 0;
            _intItem2.Value := 1;
            _intItem3.Value := 2;
            _intItem4.Value := 3;

            _list.Append(REF(_intItem1));
            _list.Append(REF(_intItem2));
            _list.Append(REF(_intItem3));
            _list.Append(REF(_intItem4));

            _list.ForAll(_addOperation);

            Assert.Equal(_intItem1.Value, 1);
            Assert.Equal(_intItem2.Value, 2);
            Assert.Equal(_intItem3.Value, 3);
            Assert.Equal(_intItem4.Value, 4);
        END_METHOD
    END_CLASS

    CLASS ComparatorMock IMPLEMENTS IComparator
        VAR PUBLIC
            CompareMock : CompareMock;
        END_VAR

        METHOD PUBLIC MockReset
            CompareMock.Reset();
        END_METHOD

        METHOD PUBLIC Compare : INT
            VAR_INPUT
                item : REF_TO LinkedListItem;
            END_VAR

            CompareMock.IncrementCallCount();
            CompareMock.Item := item;
            Compare := CompareMock.Value;
        END_METHOD
    END_CLASS

    CLASS AddOperation IMPLEMENTS IOperation
        METHOD PUBLIC Operate
            VAR_INPUT
                item : REF_TO LinkedListItem;
            END_VAR

            VAR_TEMP
                _item : REF_TO TestIntItem;
            END_VAR

            _item ?= item;

            IF _item <> NULL THEN
                _item^.Value := _item^.Value + 1;
            END_IF;
        END_METHOD
    END_CLASS

    CLASS CompareMock EXTENDS MethodMock
        VAR PUBLIC
            Item : REF_TO LinkedListItem;
            Value : INT;
        END_VAR

        METHOD PUBLIC OVERRIDE Reset
            SUPER.Reset();
            Item := NULL;
            Value := -1;
        END_METHOD
    END_CLASS

    CLASS TestItem EXTENDS LinkedListItem
    END_CLASS

    CLASS TestIntItem EXTENDS LinkedListItem
        VAR PUBLIC
            Value : INT;
        END_VAR
    END_CLASS

END_NAMESPACE