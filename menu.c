#include <stdio.h>
#include <stdlib.h>
#include <conio.h>
#include <windows.h>

void menu1(unsigned int y){
    int i, j, k;

    printf("\n\n\n\n\t\xC9");
    for(i = 0; i < 96; i++){
        printf("\xCD");
    }
        printf("\xBB");

    for(j = 0; j < 5; j++){
        printf("\n\t\xBA                                                                                                \xBA");
    }

    printf("\n\t\xBA           ####### #######  ######## ######## ##  ## #######  ###  ## ########                  \xBA");
    printf("\n\t\xBA                 ##      ##                ## ## ##        ## ###  ##    ###                    \xBA");
    printf("\n\t\xBA            ######  ######   #######  ####### ####    ##   ## ###  ##    ###                    \xBA");
    printf("\n\t\xBA            ###  ## ##  ##   ###      ###  ## ## ##   ##   ## ###  ##    ###                    \xBA");
    printf("\n\t\xBA            ######  ##   ##  #######  ###  ## ##  ##   #####   #####     ###                    \xBA");

    for(k = 0; k < 8; k++){
        printf("\n\t\xBA                                                                                                \xBA");
    }

    if(y == 0){
        printf("\n\t\xBA                                        -> START                                                \xBA");
        printf("\n\t\xBA                                         RANKING                                                \xBA");
        printf("\n\t\xBA                                         SETTINGS                                               \xBA");
        printf("\n\t\xBA                                         EXIT                                                   \xBA");
    }
    else if(y == 1){
        printf("\n\t\xBA                                         START                                                  \xBA");
        printf("\n\t\xBA                                        -> RANKING                                              \xBA");
        printf("\n\t\xBA                                         SETTINGS                                               \xBA");
        printf("\n\t\xBA                                         EXIT                                                   \xBA");
    }
    else if(y == 2){
        printf("\n\t\xBA                                         START                                                  \xBA");
        printf("\n\t\xBA                                         RANKING                                                \xBA");
        printf("\n\t\xBA                                        -> SETTINGS                                             \xBA");
        printf("\n\t\xBA                                         EXIT                                                   \xBA");
    }
    else if(y == 3){
        printf("\n\t\xBA                                         START                                                  \xBA");
        printf("\n\t\xBA                                         RANKING                                                \xBA");
        printf("\n\t\xBA                                         SETTINGS                                               \xBA");
        printf("\n\t\xBA                                        -> EXIT                                                 \xBA");
    }
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
void menu(){

    unsigned int y = 0, z, a = 0;
    char x, c;

    while(a != 1){
            do{
            switch(x){
            case 72:
                y--;
                break;
            case 80:
                y++;
                break;
        }
            y = y % 4;
            if(y == 0){
                system("cls");
                menu1(y);
                z = 0;
            }
            else if(y == 1){
                system("cls");
                menu1(y);
                z = 1;
            }
            else if(y == 2){
                system("cls");
                menu1(y);
                z = 2;
            }
            else if(y == 3){
                system("cls");
                menu1(y);
                z = 3;
            }
            x = getch();
        }while(x != 13);
        x = 0;
            do{
            if(z == 0){
                system("cls");
                game();
            }
            else if(z == 1){
                system("cls");
                ranking();
            }
            else if(z == 2){
                system("cls");
                settings();
                menu();
            }
            else if(z == 3){
                system("cls");
                Sleep(5000);
                a++;
                exit(0);
            }
            if(z < 3);{
                c = getch();
            }
            }while(c != 033);
    }
}
