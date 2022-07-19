const std = @import("std");
const log = std.log;
const debug = std.debug;
const mem = std.mem;

/// Errors associated with the array struct below
pub const ArrayErr = error{
    NotFound,
    IndexOutOfBounds,
    OutOfSpace,
    NotSorted,
};


/// a growable array, which contains items of only type T, and requires an
/// internal allocator, passed in on init(). deinitialize with deinit() fn
pub fn Array(comptime T: type) type {
    return struct {
        const This = @This();

        items: []T,
        length: usize,
        capacity: usize,
        allocator: mem.Allocator,


        /// initialize a new Array instance.  Deinitialize with instance 
        /// `deinit()` method. takes in an allocator.
        pub fn init(allocator: mem.Allocator) This {
            return This {
                .items = &[_]T{},
                .length = 0,
                .capacity = 0,
                .allocator = allocator,
            };
        }

        /// deinitialize Array. no failing
        pub fn deinit(this: *This) void {
            this.allocator.destroy(this.items.ptr);
        }

        /// grows the capacity of the array
        pub fn grow(this: *This, new_capacity: usize) mem.Allocator.Error!void {
            var cap: usize = this.capacity + new_capacity;
            var old_mem = this.items.ptr[0..this.capacity];
            var new_mem = try this.allocator.reallocAtLeast(old_mem, cap);

            this.items.ptr = new_mem.ptr;
            this.capacity = cap;
        }

        /// display Array items and metadata
        pub fn display(this: *This) void {
            var i: usize = 0;
            std.debug.print(" \n{{ ", .{});
            while (i < this.length) {
                std.debug.print("{},", .{this.items.ptr[i]});
                i += 1;
            }
            std.debug.print(" }}", .{});
            
            std.debug.print("\nlength: {},\ncapacity: {}\nsorted: {}", .{ this.length, this.capacity, this.isSorted() });
        }


        pub fn slice(this: *This) []T
        {
            return this.items.ptr[0..this.length];
        }


        /// returns a bool specifing whether the array has been sorted
        pub fn isSorted(this: *This) bool {
            var i: usize = 0;
            while (i < this.length - 1) {
                if (this.items.ptr[i] > this.items.ptr[i + 1]) return false;
                i += 1;
            }
            return true;
        }

        // add an item to the end of the Array
        pub fn add(this: *This, item: T) !void {
            if (this.length >= this.capacity) try this.grow(1);
            var i: usize = 0;
            while (i < this.length) i += 1;

            this.items.ptr[i] = item;
            this.length += 1;
        }

        /// insert an item into a given index.  items will be shifted right
        /// after the index in question
        pub fn insert(this: *This, index: usize, item: T) !void {
            if (this.length >= this.capacity) try this.grow(1);

            var i: usize = this.length - 1;
            while (i >= index) {
                this.items.ptr[i + 1] = this.items.ptr[i];
                i -= 1;
            }

            this.items.ptr[index] = item;
            this.length += 1;
        }

        /// insert an item into this Array, sorted. if the array is not sorted
        /// smallest->largest, the fn will return an error.
        pub fn insertSorted(this: *This, item: T) !void {
            if (!this.isSorted()) return ArrayErr.NotSorted;
            if (this.length >= this.capacity) try this.grow(1);

            var i: usize = this.length - 1;
            while (this.items.ptr[i] > item) {
                this.items.ptr[i + 1] = this.items.ptr[i];
                i -= 1;
            }

            this.items.ptr[i + 1] = item;
            this.length += 1;
        }

        /// remove item by index
        pub fn delete(this: *This, index: usize) !void {
            if (index >= this.length) return ArrayErr.IndexOutOfBounds;

            var i: usize = index;
            while (i < this.length - 1) {
                this.items.ptr[i] = this.items.ptr[i + 1];
                i += 1;
            }

            this.length -= 1;
        }

        /// swaps elements at x and y index in the array
        pub fn swapItem(this: *This, x_index: usize, y_index: usize) void {
            var temp: T = this.items.ptr[y_index];
            this.items.ptr[y_index] = this.items.ptr[x_index];
            this.items.ptr[x_index] = temp;
        }


        /// get item by index
        pub fn get(this: *This, index: usize) !T {
            if (index < 0 or index >= this.length) return ArrayErr.IndexOutOfBounds;
            return this.items.ptr[index];
        }


        /// set item by index
        pub fn set(this: *This, index: usize, value: T) !void {
            if (index < 0 or index >= this.length) return ArrayErr.IndexOutOfBounds;
            this.items.ptr[index] = value;
        }


        // * 
        // * Search
        // * 


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
        pub fn linearSearch(this: *This, key: T) !usize {
            var i: usize = 0;
            while (i < this.length) {
                if (key == this.items.ptr[i]) {
                    this.swapItem(0, i); // optimization for future searches
                    return i;
                }
                i += 1;
            }
            return ArrayErr.NotFound;
        }

        /// search for a given key, via binary style search. needs a key of the 
        /// given type to perform the search and ordered data. if data is not 
        /// ordered, the fn will throw an error.
        /// 
        /// max time complexity is `O(log(n))` 
        pub fn binarySearch(this: *This, key: usize) !usize {
            if (!this.isSorted()) return ArrayErr.NotSorted;
            var high: usize = this.items.ptr[this.length - 1];
            var low: usize = this.items.ptr[0];
            var mid: usize = 0;

            // while low is not greater than high, we are still searching
            while (low <= high) {
                mid = ((low + high) / 2);
                // found the key
                if (key == this.items.ptr[mid]) return mid
                // key is lower
                else if (key < this.items.ptr[mid]) high = mid - 1
                // key is higher
                else low = mid + 1;
            }

            // the key was never found
            return ArrayErr.NotFound;
        }


        // * 
        // * Operations
        // * 


        /// runs the max depending on whether the data is ordered or not
        /// specified by the param ordered as a bool
        pub fn max(this: *This) T {
            if (this.isSorted()) return this.maxOrdered();
            return this.maxUnordered();
        }

        /// returns the max of the elements in an unordered list
        /// time complexity is O(n)
        fn maxUnordered(this: *This) T {
            var m = this.items.ptr[0];
            var i: usize = 1;
            while (i <= this.length - 1) {
                if (m < this.items.ptr[i]) m = this.items.ptr[i];
                i += 1;
            }
            return m;
        }

        /// assumes an ordered list and returns the last value, as 
        /// that would be max in an ordered list. 
        fn maxOrdered(this: *This) T {
            return this.items.ptr[this.length - 1]; // return the last el
        }

        /// returns the min value located in the list via whichever 
        /// method is more time efficent given ordering
        pub fn min(this: *This) T {
            if (this.isSorted()) return this.minOrdered();
            return this.minUnordered();
        }

        /// returns the min value checked against every element in the list
        fn minUnordered(this: *This) T {
            var m = this.items.ptr[0];
            var i: usize = 1;
            while (i <= this.length - 1) {
                if (m > this.items.ptr[i]) m = this.items.ptr[i];
                i += 1;
            }
            return m;
        }

        /// returns the head element, as this would be the min in an ordered 
        /// list
        fn minOrdered(this: *This) T {
            return this.items.ptr[0];
        }

        /// sums the elements in the array. time complexity is O(n).
        pub fn sum(this: *This) T {
            var acc: T = this.items.ptr[0];
            var i: usize = 1;
            while (i <= this.length - 1) {
                acc += this.items.ptr[i];
                i += 1;
            }
            return acc;
        }

        /// finds the average of the elements by utilizing the sum method
        pub fn avg(this: *This) T {
            return this.sum() / (@as(T, this.length));
        }

        // *
        // * Transformations
        // *

        /// reverses all the elements of an array, using a swap. O(n) time
        pub fn reverse(this: *This) void {
            var i: usize = 0;
            var j: usize = this.length - 1;
            var temp: T = 0;

            while (i < j) {
                temp = this.items.ptr[i];
                this.items.ptr[i] = this.items.ptr[j];
                this.items.ptr[j] = temp;

                i += 1;
                j -= 1;
            }
        }

        /// shift data to the left. head data is lost. tail data will be overwritten with 0. 
        pub fn shiftLeft(this: *This) void {
            var i: usize = 0; // start one ahead of head
            while (i < this.length) {
                this.items.ptr[i] = this.items.ptr[i + 1];
                i += 1;
            }
            this.items.ptr[this.length - 1] = 0; // overwrite final el, to remove dup
        }

        /// shifts data to the right. if len and capacity are equal, tail data is lost
        /// head data is overwritten with 0
        pub fn shiftRight(this: *This) void {
            var i: usize = this.length - 1; // start one ahead of head

            // trying to include case where len is less than cap in one condition
            while (i > 0) {
                this.items.ptr[i] = this.items.ptr[i - 1];
                i -= 1;
            }

            this.items.ptr[0] = 0; // overwrite head el
        }

        /// leverages shift to rotate the array to the left. no data loss, head
        /// data will be at the end of the array
        pub fn rotateLeft(this: *This) void {
            var head: T = this.items.ptr[0];
            this.shiftLeft();
            this.items.ptr[this.length - 1] = head;
        }

        /// leverages shift to rotate the array to the right. tail data is set
        /// at the head of the array.
        pub fn rotateRight(this: *This) void {
            var tail: T = this.items.ptr[this.length - 1];
            this.shiftRight();
            this.items.ptr[0] = tail;
        }

        /// sorts the array such that negative nums are on
        /// the left and positive on the right side. they 
        /// are not ordered otherwise
        pub fn sortLeftNegative(this: *This) void {
            var head_ptr: usize = 0;
            var tail_ptr: usize = this.length - 1;

            while (head_ptr < tail_ptr) {
                // check right for a pos #
                while (this.items.ptr[head_ptr] < 0) head_ptr += 1;
                // check left for a neg #
                while (this.items.ptr[tail_ptr] > 0) tail_ptr -= 1;

                if (head_ptr < tail_ptr) this.swapItem(head_ptr, tail_ptr);
            }
        }

        // *
        // * Struct Operations 
        // *

        /// returns an Array, by value, that is comprised of two given sorted
        /// Arrays, merged. If either array is not sorted, the fn will return a 
        /// NotSorted error.
        pub fn merge(allocator: mem.Allocator, a1: *Array(T), a2: *Array(T)) !Array(T)
        {
            if (!a1.*.isSorted() or !a2.*.isSorted()) return ArrayErr.NotSorted;

            var i: usize = 0; //a1
            var j: usize = 0; //a2
            var k: usize = 0; //a3

            var a3 = Array(T).init(allocator);
            var new_capacity = a1.capacity + a2.capacity;

            try a3.grow(new_capacity);

            while (k < (a1.length + a2.length))
            {
                if (i >= a1.length) try a3.add(a2.items.ptr[j])

                else if (j >= a2.length) try a3.add(a1.items.ptr[i])
                
                else if (a1.items.ptr[i] < a2.items.ptr[j])
                {
                    try a3.add(a1.items.ptr[i]);
                    i += 1;
                }

                else if (a2.items.ptr[j] < a1.items.ptr[i])
                {
                    try a3.add(a2.items.ptr[j]);
                    j += 1;
                }

                k += 1;
            }

            
            return a3;
        }

        /// merges two sorted arrays, discarding duplicate values. pass in an 
        /// allocator and ptrs to two sorted arrays. if the arrays are not sorted 
        /// an error will be returned. otherwise an array, by value, containing
        /// the merged set will be returned.
        pub fn mergeSet(allocator: mem.Allocator, a1: *Array(T), a2: *Array(T)) !Array(T)
        {
            if (!a1.*.isSorted() or !a2.*.isSorted()) return ArrayErr.NotSorted;

            var i: usize = 0; //a1
            var j: usize = 0; //a2
            var k: usize = 0; //a3

            var a3 = Array(T).init(allocator);
            var new_capacity = a1.capacity + a2.capacity;
            var new_len = a1.length + a2.length;

            try a3.grow(new_capacity);

            while (k < new_len)
            {
                if (i >= a1.length) try a3.add(a2.items.ptr[j])

                else if (j >= a2.length) try a3.add(a1.items.ptr[i])

                // duplicate handling 
                else if (a1.items.ptr[i] == a2.items.ptr[j]) {
                    try a3.add(a1.items.ptr[i]); 
                    i += 1;
                    j += 1; 
                    new_len -= 1; 
                }

                else if (a1.items.ptr[i] < a2.items.ptr[j])
                {
                    try a3.add(a1.items.ptr[i]);
                    i += 1;
                }

                else if (a2.items.ptr[j] < a1.items.ptr[i])
                {
                    try a3.add(a2.items.ptr[j]);
                    j += 1;
                }

                k += 1;
 
            }

            return a3;
        }


        /// combines the common elements of two sorted arrays of unique elements 
        /// if one of the arrays is not sorted, an error will be returned. Otherwise,
        /// an Array of common elements will be returned. 
        /// this fn takes in an allocator, and ptrs to two sorted arrays
        pub fn intersectSet(allocator: mem.Allocator, a1: *Array(T), a2: *Array(T)) !Array(T) {
            if (!a1.*.isSorted() or !a2.*.isSorted()) return ArrayErr.NotSorted;

            var i: usize = 0; //a1
            var j: usize = 0; //a2
            var k: usize = 0; //a3

            var a3 = Array(T).init(allocator);
            var new_capacity = a1.capacity + a2.capacity;
            var new_len = a1.length + a2.length;

            try a3.grow(new_capacity);

            while (k < new_len)
            {
                if (i >= a1.length or j >= a2.length) break; 
                if (a1.items.ptr[i] < a2.items.ptr[j])
                {
                    i += 1;
                }
                else if (a2.items.ptr[j] < a1.items.ptr[i])
                {
                    j += 1;
                }
                // duplicate handling 
                else if (a1.items.ptr[i] == a2.items.ptr[j]) {
                    try a3.add(a1.items.ptr[i]); 
                    i += 1;
                    j += 1; 
                }
                k += 1;
            }

            return a3;
        }


        /// returns an array which contains only the elements unique to `a` between
        /// both `a` and `b` sorted arrays.  you will need to pass in an allocator,
        /// and the ordered array from which you would like the unique values as `a`
        /// the set you are checking against will be `b`. the function will return an 
        /// error if the sets are not ordered, otherwise it will return an ordered array,
        /// containing elements unique to set a.
        pub fn differenceSet(allocator: mem.Allocator, a: *Array(T), b: *Array(T)) !Array(T) {
            if (!a.*.isSorted() or !b.*.isSorted()) return ArrayErr.NotSorted;

            var i: usize = 0; //a1
            var j: usize = 0; //a2
            var k: usize = 0; //a3

            var c = Array(T).init(allocator);
            var search_len = a.length + b.length;

            // it shouldnt be larger than a len in this case
            try c.grow(a.length); 

            while (k < search_len)
            {
                // we've run out of b items, but there are 
                // still a items.  add the rest of the a's 
                // to c and then break.
                if (j >= b.length and i < a.length) {
                    while (i < a.length)
                    {
                        try c.add(a.items.ptr[i]);
                        i += 1;
                    }
                    break;
                }

                // we're out a's. break here 
                if (i >= a.length) break;


                // common el case: keep going, inc both i and j
                if (a.items.ptr[i] == b.items.ptr[j]) {
                    i += 1;
                    j += 1;
                }

                // a is bigger than b, keep going and inc j
                else if (a.items.ptr[i] > b.items.ptr[j]) {
                    j += 1; // check next b spot
                }

                // a is determined unique, add and inc i
                else if (a.items.ptr[i] < b.items.ptr[j]) {
                    try c.add(a.items.ptr[i]);
                    i += 1; // check next a spot
                    k += 1; // move to next c spot
                }

                
            }

            return c;
        }


    }; // end return This {}
} // end pub fn Array(T) {}