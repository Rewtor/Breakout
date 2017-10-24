#include <stdio.h>
#include <stdlib.h>
#include <conio.h>
#include <windows.h>
#define ALTURA 40
#define LARG 60

void game(){
    unsigned char i, j, tab[ALTURA][LARG] = {0};

    for(i = 0; i < ALTURA; i++){
        for(j = 0; j < LARG; j++){
            if(i == 0 || j == 0 || i == ALTURA - 1 || j == LARG - 1){
                tab[i][j] = 219;
            }
        }
    }


    for(i = 0; i < ALTURA; i++){
        for(j = 0; j < LARG; j++){
            printf("%c", tab[i][j]);
        }
        printf("\n");
    }
}
