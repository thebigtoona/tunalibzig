const std = @import("std");

/// an array of contiguous elements 
pub fn Array(comptime T: type, capacity: usize) type {
    return struct {
        const This = @This();

        pub const ArrayErr = error{
            NotFound,
            IndexOutOfBounds,
            OutOfSpace,
            NotSorted,
        };

        capacity: usize,
        items: *[capacity]T,
        length: usize,
        allocator: std.mem.Allocator,

        /// initialize a new array without any data, to the capacity specified 
        /// on creation for the type specified.  this requires any allocator.
        pub fn init(allocator: std.mem.Allocator) !This {
            return This{
                .capacity = capacity,
                .items = (try allocator.create([capacity]T)),
                .length = 0,
                .allocator = allocator,
            };
        }

        /// print the elements of the array, ignoring the empty slots at the end 
        pub fn display(this: *This) void {
            var i: usize = 0;
            std.debug.print("\n", .{});
            while (i < this.length) {
                std.debug.print("{}, ", .{this.items[i]});
                i += 1;
            }
            std.debug.print("\n", .{});
        }


        /// returns a bool specifing whether the array has been sorted
        pub fn isSorted(this: *This) bool
        {
            var i: usize = 0;
            while (i<this.length-1)
            {
                if (this.items[i] > this.items[i+1]) return false;
                i += 1;
            }
            return true;
        }


        /// add another element at the end of the array, provided the capacity
        /// will allow for it. 
        pub fn append(this: *This, element: T) !void {
            if (this.length >= this.capacity) return ArrayErr.OutOfSpace;

            this.items[this.length] = element;
            this.length += 1;
        }

        /// insert into the array at a given index. elements are shifted 
        /// right in the array to make room. only works if there is space
        /// left in the array for another item.
        pub fn insert(this: *This, index: usize, element: T) !void {
            // we need to know if we have room for this
            if (this.length >= this.capacity) return ArrayErr.OutOfSpace;

            var i: usize = this.length - 1;

            while (i >= index) {
                this.items.*[i + 1] = this.items.*[i];
                i -= 1;
            }

            this.items[index] = element;
            this.length += 1;
        }


        /// inserts into a sorted list provided there is capacity to do so
        /// if there is no space, or the list is not sorted, 
        /// the fn will return an err.
        pub fn insertSorted(this: *This, item: T) !void {
            if (this.length == this.capacity) return ArrayErr.OutOfSpace;
            if (!this.isSorted()) return ArrayErr.NotSorted;
            var i: usize = this.length-1;
            while (this.items[i] > item)
            {
                this.items.*[i + 1] = this.items.*[i];
                i -= 1;
            }

            this.items[i+1] = item;
            this.length += 1;
        }


        /// remove item by index
        /// time complexity: `O(n)`
        pub fn delete(this: *This, index: usize) !void {
            if (index > this.length) return ArrayErr.IndexOutOfBounds;

            var i: usize = index;
            while (i < this.length - 1) {
                // shift left
                this.items[i] = this.items[i + 1];
                i += 1;
            }

            this.length -= 1;
        }

        /// runs optimized search based on whether the data is ordered
        /// if ordered, the data will run on binary search, otherwise,
        /// it will run a linear search
        pub fn search(this: *This, key: T) !usize {
            if (this.isSorted()) return this.binarySearch(key);
            return this.linearSearch(key);
        }

        /// search for index of key returns error if not found. 
        /// repeated searches for the same key will be faster, as this 
        /// method contains a swap with head
        ///
        /// max time complexity: `O(n)`
        fn linearSearch(this: *This, key: T) !usize {
            var i: usize = 0;
            while (i < this.length) {
                if (key == this.items.*[i]) {
                    this.swapElement(0, i); // optimization for future searches
                    return i;
                }
                i += 1;
            }
            return ArrayErr.NotFound;
        }

        /// **YOU MUST ORDER THE DATA BEFORE USE for accurate results.** 
        /// search for a given key, via binary style search. needs a key of the 
        /// given type to perform the search and ordered data.
        /// 
        /// max time complexity is `O(log(n))` 
        fn binarySearch(this: *This, key: usize) !usize {
            var high: usize = this.items.*[this.length - 1];
            var low: usize = this.items.*[0];
            var mid: usize = 0;

            // while low is not greater than high, we are still searching
            while (low <= high) {
                mid = ((low + high) / 2);
                // found the key
                if (key == this.items.*[mid]) return mid
                // key is lower
                else if (key < this.items.*[mid]) high = mid - 1
                // key is higher
                else low = mid + 1;
            }

            // the key was never found
            return ArrayErr.NotFound;
        }

        /// retrieve an element by index. returns an error if the given index
        /// was out of range.
        pub fn get(this: *This, index: usize) !T {
            if (index < 0 or index >= this.length) return ArrayErr.IndexOutOfBounds;
            return this.items.*[index];
        }

        /// set the given index to a value specified. returns an error if the 
        /// index given was not in range.
        pub fn set(this: *This, index: usize, value: T) !void {
            if (index < 0 or index >= this.length) return ArrayErr.IndexOutOfBounds;
            this.items.*[index] = value;
        }

        /// runs the max depending on whether the data is ordered or not
        /// specified by the param ordered as a bool
        pub fn max(this: *This, ordered: bool) T {
            if (ordered) return this.maxOrdered();
            return this.maxUnordered();
        }

        /// returns the max of the elements in an unordered list
        /// time complexity is O(n)
        fn maxUnordered(this: *This) T {
            var m = this.items.*[0];
            var i: usize = 1;
            while (i <= this.length - 1) {
                if (m < this.items.*[i]) m = this.items.*[i];
                i += 1;
            }
            return m;
        }

        /// assumes an ordered list and returns the last value, as 
        /// that would be max in an ordered list. 
        fn maxOrdered(this: *This) T {
            return this.items.*[this.length - 1]; // return the last el
        }

        /// returns the min value located in the list via whichever 
        /// method is more time efficent given ordering
        pub fn min(this: *This, ordered: bool) T {
            if (ordered) return this.minOrdered();
            return this.minUnordered();
        }

        /// returns the min value checked against every element in the list
        fn minUnordered(this: *This) T {
            var m = this.items.*[0];
            var i: usize = 1;
            while (i <= this.length - 1) {
                if (m > this.items.*[i]) m = this.items.*[i];
                i += 1;
            }
            return m;
        }

        /// returns the head element, as this would be the min in an ordered 
        /// list
        fn minOrdered(this: *This) T {
            return this.items.*[0];
        }

        /// sums the elements in the array. time complexity is O(n).
        pub fn sum(this: *This) T {
            var acc: T = this.items.*[0];
            var i: usize = 1;
            while (i <= this.length - 1) {
                acc += this.items.*[i];
                i += 1;
            }
            return acc;
        }


        /// finds the average of the elements by utilizing the sum method
        pub fn avg(this: *This) T {
            return this.sum()/(@as(T, this.length));
        }


        /// reverses all the elements of an array, using a swap. O(n) time
        pub fn reverse(this: *This) void {
            var i: usize = 0;
            var j: usize = this.length-1;
            var temp: T = 0;

            while (i < j)
            {
                temp = this.items.*[i];
                this.items.*[i] = this.items.*[j];
                this.items.*[j] = temp;

                i += 1;
                j -= 1;
            }
        }


        /// shift data to the left. head data is lost. tail data will be overwritten with 0. 
        pub fn shiftLeft(this: *This) void {
            var i: usize = 0; // start one ahead of head 
            while (i < this.length)
            {
                this.items.*[i] = this.items.*[i+1];
                i += 1;
            }
            this.items.*[this.length-1] = 0; // overwrite final el, to remove dup 
        }

        /// shifts data to the right. if len and capacity are equal, tail data is lost
        /// head data is overwritten with 0
        pub fn shiftRight(this: *This) void 
        {
            var i: usize = this.length-1; // start one ahead of head 

            // trying to include case where len is less than cap in one condition
            while (i > 0)
            {
                this.items.*[i] = this.items.*[i-1];
                i -= 1;
            }
            
            this.items.*[0] = 0; // overwrite head el
        }


        /// leverages shift to rotate the array to the left. no data loss, head
        /// data will be at the end of the array
        pub fn rotateLeft(this: *This) void {
            var head: T = this.items.*[0];
            this.shiftLeft();
            this.items.*[this.length-1] = head;
        }


        /// leverages shift to rotate the array to the right. tail data is set
        /// at the head of the array.
        pub fn rotateRight(this: *This) void {
            var tail: T = this.items.*[this.length-1]; 
            this.shiftRight();
            this.items.*[0] = tail;
        }


        /// sorts the array such that negative nums are on
        /// the left and positive on the right side. they 
        /// are not ordered otherwise
        pub fn sortLeftNegative(this: *This) void
        {
            var head_ptr: usize = 0;
            var tail_ptr: usize = this.length-1;

            while (head_ptr < tail_ptr)
            {
                // check right for a pos #
                while(this.items[head_ptr] < 0) head_ptr += 1;
                // check left for a neg #
                while(this.items[tail_ptr] > 0) tail_ptr -= 1;
            
                if (head_ptr < tail_ptr) this.swapElement(head_ptr, tail_ptr);
            }
        }


        /// swaps elements at x and y index in the array
        pub fn swapElement(this: *This, x_index: usize, y_index: usize) void
        {
            var temp: T = this.items.*[y_index];
            this.items[y_index] = this.items.*[x_index];
            this.items[x_index] = temp;
        }


        pub fn deinit(this: *This) void {
            this.allocator.destroy(this.items);
        }
    };
}
