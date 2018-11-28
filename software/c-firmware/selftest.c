#include <libtinyc.h>
#include <libspu32.h>

void error(char i) {
    set_leds_value(i);
    while(1) {}
}

/*
* First check: A naive way to compute prime numbers
*/

int isPrime(int candidate) {
    int test = (candidate/2)+1;
    while(--test > 1) {
        if((candidate / test) * test == candidate) {
            return 0;
        }
    }
    return 1;
}

int naivePrime(int* primes, int n) {
    int sum = 0;
    int last = 1;
    int idx = 0;
    while(idx < n) {
        int candidate = last + 1;

        while(!isPrime(candidate)) {
            candidate++;
        }

        sum += candidate;
        last = candidate;
        primes[idx++] = candidate;
    }

    return sum;
}

void checkPrime() {
    int prime1[100];

    int sum1 = naivePrime(prime1, sizeof(prime1)/sizeof(prime1[0]));
    int sum2 = 0;
    for(int idx = 0; idx < sizeof(prime1)/sizeof(prime1[0]); ++idx) {
        sum2 += prime1[idx];
    }

    if(sum1 != sum2 || sum1 != 24133) {
        printf("sum of first 100 prime numbers does not check out!\n\r");
        error(1);
    } else {
        printf("prime number test passed\n\r");
    }
}

/*
* Second check: Naive sorting algorithm
*/

void naiveSort(int* numbers, int n) {
    char finished = 1;
    int tmp = 0;

    do {
        finished = 1;
        for(int idx = 0; idx < (n-1); ++idx) {
            if(numbers[idx+1] < numbers[idx]) {
                finished = 0;
                tmp = numbers[idx];
                numbers[idx] = numbers[idx+1];
                numbers[idx+1] = tmp;
            }
        }

    } while(!finished);

}


void checkSort() {
    int numbers[100];

    // fill up array with 1 to 100... backwards
    for(int idx = 0; idx < 100; ++idx) {
        numbers[idx] = 100 - idx;
    }

    naiveSort(numbers, 100);

    // check sorting result
    char err = 0;
    for(int idx = 0; idx < 99; ++idx) {
        if(numbers[idx] > numbers[idx+1]) {
            err = 1;
            break;
        }
    }

    if(err) {
        printf("sorting test failed\n\r");
        error(2);
    } else {
        printf("sorting test passed\n\r");
    }

}


int main() {

    char pass = 0;


    while(1) {
        set_leds_value(pass++);
        checkPrime();
        checkSort();

    }

	
}

