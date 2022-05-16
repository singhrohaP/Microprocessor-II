#include <stdio.h>
#include <stdlib.h>
#include "pico/stdlib.h"
#include "hardware/gpio.h"
#include "pico/multicore.h" //! Required for using multiple cores on the RP2040.
#include "assign02.pio.h"
#include "assign02.h"
#include "hardware/structs/watchdog.h"

#define IS_RGBW true  //! Will use RGBW format
#define NUM_PIXELS 1  //! There is 1 WS2812 device in the chain
#define WS2812_PIN 28 //! The GPIO pin that the WS2812 connected to

int button_buffer;  //! shared variable between asm and c code, stores the morse code buffer
int number_of_bits; //! shared variable between asm and c code, stores the number of bits in the buffer
int isSpace;
int prev;  //! Store the previous state of  button_buffer
int lives; //! Player lives

static inline void put_pixel(uint32_t pixel_grb)
{
    pio_sm_put_blocking(pio0, 0, pixel_grb << 8u);
}

static inline uint32_t urgb_u32(uint8_t r, uint8_t g, uint8_t b)
{
    return ((uint32_t)(r) << 8) |
           ((uint32_t)(g) << 16) |
           (uint32_t)(b);
}

// Declare the main assembly code entry point.

/**
 * @brief
 * Initialise a GPIO pin – see SDK for detail on gpio_init()
 * @param pin
 */
void asm_gpio_init(uint pin)
{
    gpio_init(pin);
}

/**
 * @brief
 * Set direction of a GPIO pin – see SDK for detail on gpio_set_dir()
 * @param pin
 * @param out
 */
void asm_gpio_set_dir(uint pin, bool out)
{
    gpio_set_dir(pin, out);
}

/**
 * @brief
 * Get the value of a GPIO pin – see SDK for detail on gpio_get()
 * @param pin
 * @return bool
 */
bool asm_gpio_get(uint pin)
{
    return gpio_get(pin);
}

/**
 * @brief
 * Set the value of a GPIO pin – see SDK for detail on gpio_put()
 * @param pin
 * @param value
 */
void asm_gpio_put(uint pin, bool value)
{
    gpio_put(pin, value);
}

/**
 * @brief
 * Enable falling-edge interrupt – see SDK for detail on gpio_set_irq_enabled()
 * TODO change this, right now it resembles the behaviour of GPIO_IRQ_HIGH
 * @param pin
 */
void asm_gpio_set_irq(uint pin)
{
    gpio_set_irq_enabled(pin, GPIO_IRQ_EDGE_RISE | GPIO_IRQ_EDGE_FALL, true);
}

/**
 * @brief
 * set up code to run on core 1
 */
void core1_entry()
{
    while (1)
    {
        int32_t (*func)() = (int32_t(*)())multicore_fifo_pop_blocking();
        int32_t p = multicore_fifo_pop_blocking();
        int32_t result = (*func)(p);
        multicore_fifo_push_blocking(result);
    }
}

//-------------UTILITY FUNCTIONS------------
/**
 * @brief
 * This function return the bits pointer and enables other parts of code to read the buffer information
 * @return int
 */
int *get_bits(int buffer, int number_of_bits)
{
    int *bits = malloc(sizeof(int) * number_of_bits);

    int k;
    for (k = 0; k < number_of_bits; k++)
    {
        int mask = 1 << k;
        int masked_n = buffer & mask;
        int thebit = masked_n >> k;
        bits[k] = thebit;
    }

    return bits;
}

/**
 * @brief
 * Function to clear the console
 */
void clearscreen()
{
    for (int i = 0; i < 50; i++)
    {
        printf("\n");
    }
}

/**
 * @brief
 * Resets the current word buffer
 */
void reset_buffer()
{
    button_buffer = 1;
    number_of_bits = 0;
    return;
}

/**
 * @brief
 * check if the code stored in the buffer matches the code of the letter in the index
 * @param index
 * @return int
 */
int check_morse(int index)
{

    if (number_of_bits > 7)
    {
        return 0;
    }

    int *bits = get_bits(button_buffer, number_of_bits);
    for (int i = 0; i < number_of_bits; i++)
    {
        if (bits[number_of_bits - i - 1] != (int)(codeDict[index][i + 1]) - 45)
        {
            return 0;
        }
    }

    if (codeDict[index][number_of_bits + 1] != '\0')
    {
        return 0;
    }

    return 1;
}

/**
 * @brief
 * Return the letter corresponding to the letter, else return ?
 * @return char
 */
char search_morse()
{
    for (int i = 0; i < 36; i++)
    {
        if (check_morse(i) == 1)
        {
            return codeDict[i][0];
        }
    }

    return '?';
}
/**
 * @brief
 * Checks if the input is a space or not
 * @return char
 */
void waitForSpace()
{
    while (isSpace == 0)
    {
    }

    isSpace = 0;
}

//-------------MAIN FUNCTIONS----------//

/**
 * @brief
 * welcome banner with group number and instructions
 */
void welcomeMessage()
{
    put_pixel(urgb_u32(0x00, 0x00, 0x7F));
    clearscreen();
    printf("+---------------------------------------------------------+\n");
    printf("|\t\t Microprocessor Systems\t\t\t  |\n");
    printf("|\t\t   CSU23021-202122\t\t          |\n");
    printf("|\t\t Assignment 2 by Group 9\t\t  |\n");
    printf("+---------------------------------------------------------+\n");
    printf("|    #        # # # #      #      # # # #  #       # \t  |\n");
    printf("|    #        #          #   #    #     #  # #     # \t  |\n");
    printf("|    #        # # # #  # # # # #  # # # #  #   #   # \t  |\n");
    printf("|    #        #        #       #  #   #    #     # # \t  |\n");
    printf("|    # # # #  # # # #  #       #  #     #  #       # \t  |\n");
    printf("| \t\t\t\t\t\t\t\t\t\t\t\t\t\t  |\n");

    printf("|  #               #  # # # #  # # # #   # # #  # # # #   |\n");
    printf("|  # #           # #  #     #  #     #  #       #         |\n");
    printf("|  #   #       #   #  #     #  # # # #  # # #   # # # #   |\n");
    printf("|  #     #   #     #  #     #  #   #         #  #         |\n");
    printf("|  #       #       #  # # # #  #     #  # # #   # # # #   |\n");
    printf("+---------------------------------------------------------+\n");
    printf("|\tUSE GP21 TO ENTER A SEQUENCE TO BEGIN\t\t  |\n");
    printf("+---------------------------------------------------------+\n");
    printf("|\t \"-----\" - LEVEL 01 - CHARS (EASY)\t\t  |\n");
    printf("|\t \".----\" - LEVEL 02 - CHARS (HARD)\t\t  |\n");
    printf("|\t \"..---\" - LEVEL 03 - WORDS (EASY)\t\t  |\n");
    printf("|\t \"...--\" - LEVEL 04 - WORDS (HARD)\t\t  |\n");
    printf("+---------------------------------------------------------+\n");
}
/**
 * @brief
 * function for each level printing output based on the user input
 * @param level
 * @param randomIndex
 * @param score
 * @param lives
 */
void printCurrentLevel(int level, int randomIndex, int score, int lives)
{
    switch (level)
    {
    case 1:

        clearscreen();
        printf("\nLives: %d\nScore:%d\nLetter to print:%c Code:", lives, score, codeDict[randomIndex][0]);
        for (int i = 1; codeDict[randomIndex][i] != '\0'; i++)
        {
            printf("%c", codeDict[randomIndex][i]);
        }
        printf("\n");
        return;
        break;
    case 2:

        clearscreen();
        printf("\nLives: %d \nScore:%d\nLetter to print:%c", lives, score, codeDict[randomIndex][0]);
        // Printing for debugging purposes
        // for (int i = 1; codeDict[randomIndex][i] != '\0'; i++)
        // {
        //     printf("%c", codeDict[randomIndex][i]);
        // }
        printf("\n");
        return;
        break;
    case 3:

        clearscreen();
        printf("\nLives: %d\nScore:%d\nWord to print:", lives, score);
        for (int i = 0; wordDict[randomIndex][i] != '\0'; i++)
        {
            printf("%c", wordDict[randomIndex][i]);
        }
        printf("\n");

        for (int i = 0; i < 3; i++)
        {
            for (int j = 0; j < 36; j++)
            {
                if (wordDict[randomIndex][i] == codeDict[j][0])
                {
                    printf("\\ ");
                    for (int k = 1; codeDict[j][k] != '\0'; k++)
                    {
                        printf("%c", codeDict[j][k]);
                    }
                }
            }
        }

        printf("\n");
        return;
        break;
    case 4:

        clearscreen();
        printf("\nLives:%d\nScore:%d\nWord to print:", lives, score);
        for (int i = 0; wordDict[randomIndex][i] != '\0'; i++)
        {
            printf("%c", wordDict[randomIndex][i]);
        }
        printf("\n");
        // Printing for debuggin purposes
        // for (int i = 0; i < 3; i++)
        // {
        //     for (int j = 0; j < 36; j++)
        //     {
        //         if (wordDict[randomIndex][i] == codeDict[j][0])
        //         {
        //             printf("\\ ");
        //             for (int k = 1; codeDict[j][k] != '\0'; k++)
        //             {
        //                 printf("%c", codeDict[j][k]);
        //             }
        //         }
        //     }
        // }
        printf("\n");
        return;
        break;

    default:
        break;
    }
}

/**
 * @brief
 * printing a count down to let the player know that the game is about to begin
 * @param level
 * @param randomIndex
 * @param score
 * @param lives
 */
void countDown(int level, int randomIndex, int score, int lives)
{
    put_pixel(urgb_u32(0x00, 0x7F, 0x00));
    waitForSpace();
    watchdog_update();
    printCurrentLevel(level, randomIndex, score, lives);
    printf("3  ");
    waitForSpace();
    watchdog_update();
    printCurrentLevel(level, randomIndex, score, lives);
    printf("3  2  ");
    waitForSpace();
    watchdog_update();
    printCurrentLevel(level, randomIndex, score, lives);
    printf("3  2  1  ");
    waitForSpace();
    watchdog_update();
    printCurrentLevel(level, randomIndex, score, lives);
    printf("GO!\n");
}

/**
 * @brief
 * funtion to reset the buffer and printing the output
 */

char returnInput()
{
    while (true)
    {
        if (button_buffer != prev && number_of_bits > 0)
        {

            int *bits = get_bits(button_buffer, number_of_bits);
            for (int j = number_of_bits - 1; j >= 0; j--)
            {
                printf("%c", bits[j] + 45);
            }
            printf("\n");
            prev = button_buffer;

            if (number_of_bits >= 32)
            {
                reset_buffer();
            }
        }

        if (isSpace == 1)
        {
            isSpace = 0;
            char result = search_morse();
            return result;
        }
    }
}
/**
 * @brief
 * implementation of task 1
 * @return int
 */
int task1()
{
    clearscreen();
    reset_buffer();
    put_pixel(urgb_u32(0x00, 0x7F, 0x00));
    printf("\n\n\t\tWELCOME TO LEVEL 1\n\n");
    int score = 0;
    int level = 1;
    int lives = 3;
    int nextScore = 0;
    int addLives = 3;

    while (true)
    {
        reset_buffer();
        watchdog_update();
        int randomIndex = rand() % 36;

        countDown(level, randomIndex, score, lives);

        char result = returnInput();

        if (lives == 0)
        {
            put_pixel(urgb_u32(0x7F, 0x00, 0x00));
            printf("\n\n\t\tSorry! You're out of lives\n\n");
            return 0;
        }
        if (nextScore == 5)
        {
            clearscreen();
            printf("\n\n\t\tCongrats! You got 5 in a row. Move to Level 2\n\n");
            return 1;
        }

        if (result == codeDict[randomIndex][0])
        {
            score++;
            nextScore++;
            if (addLives > 0)
            {
                lives++;
                addLives--;
                put_pixel(urgb_u32(0x80, 0x00, 0x80));
            }

            waitForSpace();
            watchdog_update();
            printf("Correct! Character decoded to: %c\nScore: %d\n", result, score);
        }
        else
        {
            if (score > 0)
            {
                score--;
                nextScore = 0;
            }
            lives--;
            put_pixel(urgb_u32(0x7F, 0x00, 0x00));
            waitForSpace();
            watchdog_update();
            printf("Incorrect! Charater decoded to: %c\nScore: %d\n", result, score);
        }
    }
}
/**
 * @brief
 * implementation of task 2
 * @return int
 */
int task2()
{
    clearscreen();
    reset_buffer();
    put_pixel(urgb_u32(0x00, 0x7F, 0x00));
    printf("\n\n\t\tWELCOME TO LEVEL 2\n\n");
    int score = 0;
    int level = 2;
    int lives = 3;
    int nextScore = 0;
    int addLives = 3;
    while (true)
    {
        reset_buffer();
        watchdog_update();
        int randomIndex = rand() % 36;

        countDown(level, randomIndex, score, lives);

        char result = returnInput(); // randomIndex, 0);

        if (lives == 0)
        {
            clearscreen();
            printf("\n\n\t\tSorry! You're out of lives\n\n");
            put_pixel(urgb_u32(0x7F, 0x00, 0x00));
            return 0;
        }
        if (nextScore == 5)
        {
            clearscreen();
            printf("\n\n\t\tCongrats! You got 5 in a row. Move to LEVEL 3\n\n");
            return 1;
        }

        if (result == codeDict[randomIndex][0])
        {
            score++;
            nextScore++;
            if (addLives > 0)
            {
                lives++;
                addLives--;
                put_pixel(urgb_u32(0x80, 0x00, 0x80));
            }

            waitForSpace();
            watchdog_update();
            printf("Score: %d\nCorrect! Character decoded to: %c\nLives : %d", score, result, lives);
        }
        else
        {
            if (score > 0)
            {
                score--;
                nextScore = 0;
            }
            lives--;
            put_pixel(urgb_u32(0x7F, 0x00, 0x00));
            waitForSpace();
            watchdog_update();
            printf("Incorrect! Charater decoded to: %c\nLives : %d", result, lives);
        }
    }
}
/**
 * @brief
 * implementation of task 3
 * @return int
 */
int task3()
{
    clearscreen();
    reset_buffer();
    put_pixel(urgb_u32(0x00, 0x7F, 0x00));
    printf("\n\n\t\tWELCOME TO LEVEL 3\n\n");
    int score = 0;
    int level = 3;
    int lives = 3;
    int nextScore = 0;
    int addLives = 3;
    watchdog_update();
    // int flag = 0;
    // int wordIndex = 0;
    //
    while (true)
    {
        reset_buffer();
        watchdog_update();
        int randomIndex = rand() % 16;

        countDown(level, randomIndex, score, lives);

        char result = returnInput(); // randomIndex, 0);

        if (lives == 0)
        {
            clearscreen();
            printf("\n\n\t\tSorry! You're out of lives\n\n");
            put_pixel(urgb_u32(0x7F, 0x00, 0x00));
            return 0;
        }

        if (result == wordDict[randomIndex][0])
        {
            watchdog_update();
            printf("\nEnter 2nd Character:\n");
            reset_buffer();
            watchdog_update();
            char result2 = returnInput(); // randomIndex, 0);

            printf("\nEnter 3rd character\n");
            reset_buffer();
            watchdog_update();
            char result3 = returnInput(); //(randomIndex, 0);
            if (result2 == wordDict[randomIndex][1] && result3 == wordDict[randomIndex][2])
            {
                score++;
                nextScore++;
                if (addLives > 0)
                {
                    lives++;
                    addLives--;
                    put_pixel(urgb_u32(0x80, 0x00, 0x80));
                }
                waitForSpace();
                watchdog_update();
                printf("Score: %d\nCorrect!\nLives : %d", score, result, result2, result3, lives);
                if (nextScore == 5)
                {
                    clearscreen();
                    printf("\n\n\t\tCongrats! You got 5 in a row. Move to Task 4\n\n");
                    watchdog_update();
                    return 1;
                }
            }
            else
            {
                if (score > 0)
                {
                    score--;
                    nextScore = 0;
                }
                lives--;
                // wordIndex = 0;
                put_pixel(urgb_u32(0x7F, 0x00, 0x00));
                waitForSpace();
                watchdog_update();
                printf("Incorrect!\nLives : %d", result, lives);
            }
        }
        else
        {
            if (score > 0)
            {
                score--;
                nextScore = 0;
            }
            lives--;
            // wordIndex = 0;
            put_pixel(urgb_u32(0x7F, 0x00, 0x00));
            waitForSpace();
            watchdog_update();
            printf("Incorrect! \nLives : %d", result, lives);
        }
    }
}
/**
 * @brief
 * implementation of task 4
 * @return int
 */
int task4()
{
    clearscreen();
    reset_buffer();
    put_pixel(urgb_u32(0x00, 0x7F, 0x00));
    printf("\n\n\t\tWELCOME TO LEVEL 4\n\n");
    int score = 0;
    int level = 4;
    int lives = 3;
    int nextScore = 0;
    int addLives = 3;
    watchdog_update();
    while (true)
    {
        reset_buffer();
        watchdog_update();
        int randomIndex = rand() % 16;

        countDown(level, randomIndex, score, lives);

        char result = returnInput(); // randomIndex, 0);

        if (lives == 0)
        {
            clearscreen();
            printf("\n\n\t\tSorry! You're out of lives\n\n");
            put_pixel(urgb_u32(0x7F, 0x00, 0x00));
            return 0;
        }

        if (result == wordDict[randomIndex][0])
        {
            printf("\nEnter 2nd Character:\n");
            reset_buffer();
            watchdog_update();
            char result2 = returnInput(); // randomIndex, 0);
            printf("\nEnter 3rd character\n");
            reset_buffer();
            watchdog_update();
            char result3 = returnInput(); // randomIndex, 0);
            if (result2 == wordDict[randomIndex][1] && result3 == wordDict[randomIndex][2])
            {
                score++;
                nextScore++;
                if (addLives > 0)
                {
                    lives++;
                    addLives--;
                    put_pixel(urgb_u32(0x80, 0x00, 0x80));
                }
                waitForSpace();
                watchdog_update();
                printf("Score: %dCorrect! \nLives : %d", score, result, result2, result3, lives);
                if (nextScore == 5)
                {
                    clearscreen();
                    printf("\n\n\t\tCongrats! You got 5 in a row. \n\n\t\tGame Over!\n\n");
                    return 1;
                }
            }
            else
            {
                if (score > 0)
                {
                    score--;
                    nextScore = 0;
                }
                lives--;
                put_pixel(urgb_u32(0x7f, 0x00, 0x00));
                waitForSpace();
                watchdog_update();
                printf("Incorrect! \nLives : %d", result, lives);
            }
        }
        else
        {
            if (score > 0)
            {
                score--;
                nextScore = 0;
            }
            lives--;
            put_pixel(urgb_u32(0x7F, 0x00, 0x00));
            waitForSpace();
            watchdog_update();
            printf("Incorrect! \nLives : %d", result, lives);
        }
    }
}
/**
 * @brief
 *  Multicore function that runs the main program on the additional core.
 * @param fico
 * @return int32_t
 */
int32_t core_1_process(int32_t fico)
{

    reset_buffer();
    int current = 0;
    int progressVar = 0;
    int locked = 0;
    while (true)
    {

        char result = returnInput();
        switch (result)
        {
        case '0':

            progressVar = task1();
            if (progressVar == 1)
            {
                locked++;
            }
            current--;
            break;
        case '1':
            if (locked >= 1)
            {
                progressVar = task2();
                if (progressVar == 1)
                {
                    locked++;
                }
                current--;
            }
            else
            {
                reset_buffer();
                clearscreen();
                printf("\n\n Level 2 is locked, Please complete Level 1\n\n");
                waitForSpace();
                watchdog_update();
                welcomeMessage();
                break;
            }
            break;

        case '2':
            if (locked >= 2)
            {
                progressVar = task3();
                if (progressVar == 1)
                {
                    locked++;
                }
                current--;
            }
            else
            {
                reset_buffer();
                clearscreen();
                printf("\n\n Level 3 is locked, Please complete Level 2 \n\n");
                waitForSpace();
                watchdog_update();
                welcomeMessage();
                break;
            }
            break;
        case '3':
            if (locked >= 3)
            {
                progressVar = task4();
                if (progressVar == 1)
                {
                    locked++;
                }
                current--;
            }
            else
            {
                reset_buffer();
                clearscreen();
                printf("\n\n Level 4 is locked, Please complete Level 3 \n\n");
                waitForSpace();
                watchdog_update();
                welcomeMessage();
                break;
            }
            break;

        default:
            reset_buffer();
            if (current == 0)
            {
                welcomeMessage();
                current++;
            }
            watchdog_update();
            break;
        }
    }
}

// Main entry point of the application
int main()
{
    button_buffer = 1;
    prev = 0;
    isSpace = 0;

    stdio_init_all(); // Initialise all basic IO

    PIO pio = pio0;
    uint offset = pio_add_program(pio, &assign02_program);
    assign02_program_init(pio, 0, offset, WS2812_PIN, 800000, IS_RGBW);
    watchdog_enable(0x7fffff, 1);

    // initialise the c code to run on CORE 1
    multicore_launch_core1(core1_entry);
    multicore_fifo_push_blocking((uintptr_t)&core_1_process);
    multicore_fifo_push_blocking(10);

    // move the address of button_buffer to r1
    asm("movs r1, %0" ::"r"(&button_buffer));
    asm("movs r2, %0" ::"r"(&number_of_bits));
    asm("movs r3, %0" ::"r"(&isSpace));
    // run the assembly code on CORE 0
    main_asm();

    return 0; // Application return code
}
