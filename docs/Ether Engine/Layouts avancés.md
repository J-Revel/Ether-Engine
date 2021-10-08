Gestion du padding :

Pb : taille et positionnement pas connus au moment du positionnement des widgets enfants => si la taille du parent dépend du contenu mais que le contenu essaye de prendre toute la place, problème

Exemple de layout non géré actuellement :
Horizontal layout dont certains éléments doivent avoir une taille adaptée au contenu, et d'autres sont fixes.

-> push_layout()
	-> element 1 taille fixe
	-> filler (taille variable)
	-> element 2 taille variable
	-> element 3
-> pop_layout()
On ne peut connaître la position finale des éléments qu'au moment du pop_layout => besoin de commandes dont la position finale n'est pas encore calculée

*A garder en tête : ces layouts complexes peuvent être imbriqués*

-> notion de commandes imbriquées ? positions/tailles relatives à une autre commande
	-> positions absolues calculées au moment de la transformation en GPU_Commands