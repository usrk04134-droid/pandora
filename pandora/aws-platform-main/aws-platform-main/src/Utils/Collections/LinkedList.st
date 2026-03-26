NAMESPACE Esab.Utils.Collections

    INTERFACE ILinkedList

        /// Adds an item to end of this list.
        /// Returns TRUE if the item was successfully added
        METHOD Append : BOOL
            VAR_INPUT
                item : REF_TO LinkedListItem;
            END_VAR
        END_METHOD

        /// Adds an item to start of this list.
        /// Returns TRUE if the item was successfully added
        METHOD Prepend : BOOL
            VAR_INPUT
                item : REF_TO LinkedListItem;
            END_VAR
        END_METHOD

        /// Pops (removes) the head of the list and returns it.
        METHOD PopHead : REF_TO LinkedListItem
        END_METHOD

        /// Returns the current number of items in the list
        METHOD Size : INT
        END_METHOD

        /// Clears the list.
        /// This will set the size to zero and clear the "next" attribute of all items.
        METHOD Clear
        END_METHOD

        /// Returns true if this list contains no items.
        METHOD Empty : BOOL
        END_METHOD

        /// Returns TRUE if the reference is present in the list.
        METHOD Contains : BOOL
            VAR_INPUT
                item : REF_TO LinkedListItem;
            END_VAR
        END_METHOD

        /// Searches the list for an item matching the prerequisite.
        /// Returns a reference to the item if found, NULL if not.
        METHOD Find : REF_TO LinkedListItem
            VAR_INPUT
                comparator : IComparator;
            END_VAR
        END_METHOD

        /// Performs an operation on all items in the list.
        METHOD ForAll
            VAR_INPUT
                operation : IOperation;
            END_VAR
        END_METHOD
    END_INTERFACE

    /// Used when searching for objects in the LinkedList
    INTERFACE IComparator
        /// Used to compare against a criteria, the input item is the item in the list that is currently investigated.
        /// This method should return "0" if the items are considered equal.
        /// A positive or negative number is interpreted as the ordering between two items.
        METHOD Compare : INT
            VAR_INPUT
                item : REF_TO LinkedListItem;
            END_VAR
        END_METHOD
    END_INTERFACE

    /// Interface of an operation, i.e. something that can be performed on all items in the list.
    INTERFACE IOperation
        /// This method will be called on all items in the list.
        METHOD Operate
            VAR_INPUT
                item : REF_TO LinkedListItem;
            END_VAR
        END_METHOD
    END_INTERFACE

    /// Abstracts a linked list collection
    /// NOTE: The items contained in the list must be memory managed by the _user of the list_.
    /// No data will be copied into this list.
    CLASS PUBLIC LinkedList IMPLEMENTS ILinkedList
        VAR PRIVATE
            _head : REF_TO LinkedListItem := NULL;
            _tail : REF_TO LinkedListItem := NULL;
        END_VAR

        VAR PRIVATE
            _size : INT := 0;
        END_VAR

        METHOD PUBLIC Append : BOOL
            VAR_INPUT
                item : REF_TO LinkedListItem;
            END_VAR

            VAR_TEMP
                _index : INT;
            END_VAR

            IF THIS.Contains(item) THEN
                Append := FALSE;
                RETURN;
            END_IF;

            IF _head = NULL AND _tail = NULL THEN
                _head := item;
                _tail := item;
            ELSE
                _tail^.SetNext(item);
                _tail := item;
            END_IF;

            _size := _size + 1;
            Append := TRUE;
        END_METHOD

        METHOD PUBLIC Prepend : BOOL
            VAR_INPUT
                item : REF_TO LinkedListItem;
            END_VAR

            IF THIS.Contains(item) THEN
                Prepend := FALSE;
                RETURN;
            END_IF;

            IF _head = NULL AND _tail = NULL THEN
                _head := item;
                _tail := item;
                _size := _size + 1;
            ELSE
                item^.SetNext(_head);
                _head := item;
            END_IF;

            _size := _size + 1;
            Prepend := TRUE;
        END_METHOD

        METHOD PUBLIC PopHead : REF_TO LinkedListItem
            VAR_TEMP
                item : REF_TO LinkedListItem := NULL;
            END_VAR

            IF THIS.Size() > 1 THEN
                item := _head;
                _head := item^.GetNext();
                item^.SetNext(NULL);
                _size := _size - 1;

                PopHead := item;
            ELSIF THIS.Size() = 1 THEN
                item := _head;
                item^.SetNext(NULL);
                _head := NULL;
                _tail := NULL;
                _size := 0;

                PopHead := item;
            ELSE
                PopHead := NULL;
            END_IF;
        END_METHOD

        METHOD PUBLIC Size : INT
            Size := _size;
        END_METHOD

        METHOD PUBLIC Clear
            WHILE _head <> NULL DO
                THIS.PopHead();
            END_WHILE;

            // Edge case, if the list is circular the size will end up at -1 otherwise
            IF _size < 0 THEN
                _size := 0;
            END_IF;
        END_METHOD

        METHOD PUBLIC Empty : BOOL
            Empty := THIS.Size() = 0;
        END_METHOD

        METHOD PUBLIC Contains : BOOL
            VAR_INPUT
                item : REF_TO LinkedListItem;
            END_VAR

            VAR_TEMP
                _item : REF_TO LinkedListItem;
                _index : INT;
            END_VAR

            _item := _head;

            WHILE _item <> NULL DO
                IF _item = item THEN
                    Contains := TRUE;
                    RETURN;
                ELSE
                    _item := _item^.GetNext();
                END_IF;
            END_WHILE;

            Contains := FALSE;
        END_METHOD

        METHOD PUBLIC Find : REF_TO LinkedListItem
            VAR_INPUT
                comparator : IComparator;
            END_VAR

            VAR_TEMP
                _item : REF_TO LinkedListItem;
            END_VAR

            _item := _head;

            WHILE _item <> NULL DO
                IF comparator.Compare(_item) = 0 THEN
                    Find := _item;
                    RETURN;
                ELSE
                    _item := _item^.GetNext();
                END_IF;
            END_WHILE;

            Find := NULL;
        END_METHOD

        METHOD PUBLIC ForAll
            VAR_INPUT
                operation : IOperation;
            END_VAR

            VAR_TEMP
                _item : REF_TO LinkedListItem;
            END_VAR

            _item := _head;

            WHILE _item <> NULL DO
                operation.Operate(_item);
                _item := _item^.GetNext();
            END_WHILE;
        END_METHOD
    END_CLASS

    CLASS LinkedListItem
        VAR PRIVATE
            _next : REF_TO LinkedListItem := NULL;
        END_VAR

        METHOD PUBLIC GetNext : REF_TO LinkedListItem
            GetNext := _next;
        END_METHOD

        METHOD PUBLIC SetNext
            VAR_INPUT
                next : REF_TO LinkedListItem;
            END_VAR

            _next := next;
        END_METHOD
    END_CLASS

END_NAMESPACE