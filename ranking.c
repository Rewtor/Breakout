#include <stdio.h>
#include <stdlib.h>
#include <conio.h>
#include <windows.h>

void rank(unsigned int y){
    int i, j, k;

    printf("\n\n\n\n\t\xC9");
    for(i = 0; i < 96; i++){
        printf("\xCD");
    }
        printf("\xBB");

    for(j = 0; j < 5; j++){
        printf("\n\t\xBA                                                                                                \xBA");
    }

    printf("\n\t\xBA                    ####### ######## ##  ##  ##  ## ### ##  ##   ######                         \xBA");
    printf("\n\t\xBA                          ##      ## ### ##  ## ##  ### ### ##  ###                             \xBA");
    printf("\n\t\xBA                     ######  ####### ######  ####   ### ######  ###  ##                         \xBA");
    printf("\n\t\xBA                     ##  ##  ###  ## ## ###  ## ##  ### ## ###  ###  ##                         \xBA");
    printf("\n\t\xBA                     ##   ## ###  ## ##  ##  ##  ## ### ##  ##   #####                          \xBA");

    for(k = 0; k < 8; k++){
        printf("\n\t\xBA                                                                                                \xBA");
    }

    if(y == 0){
        printf("\n\t\xBA                                        -> BALL COLLOR                                          \xBA");
        printf("\n\t\xBA                                         LANGUAGE                                               \xBA");
        printf("\n\t\xBA                                         USERNAME                                               \xBA");
    }
    else if(y == 1){
        printf("\n\t\xBA                                         BALL COLLOR                                            \xBA");
        printf("\n\t\xBA                                        -> LANGUAGE                                             \xBA");
        printf("\n\t\xBA                                         USERNAME                                               \xBA");
    }
    else if(y == 2){
        printf("\n\t\xBA                                         BALL COLLOR                                            \xBA");
        printf("\n\t\xBA                                         LANGUAGE                                               \xBA");
        printf("\n\t\xBA                                        -> USERNAME                                             \xBA");
    }
    printf("\n\t\xBA                                                                                                \xBA");
    printf("\n\t\xBA                                                                                                \xBA");
    printf("\n\t\xBA                                                                                                \xBA");
    printf("\n\t\xBA                                                                                                \xBA");

    int u;

    printf("\n\t\xC8");
    for(u = 0; u < 96; u++){
        printf("\xCD");
    }
        printf("\xBC");
}
void ranking(){

    int y = 0;
    char x, c;

    while(x != 033){
            switch(x){
            case 72:
                if(y == 0){
                    y = 2;
                }
                else{
                    y--;
                }
                break;
            case 80:
                if(y == 2){
                    y = 0;
                }
                else{
                    y++;
                }
                break;
        }
            //y = y % 3;
            if(y == 0){
                system("cls");
                rank(y);
            }
            else if(y == 1){
                system("cls");
                rank(y);
            }
            else if(y == 2){
                system("cls");
                rank(y);
            }
            x = getch();
    }
}


