<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreMenuCategoryRequest;
use App\Http\Requests\StoreProductRequest;
use App\Http\Requests\UpdateMenuCategoryRequest;
use App\Http\Requests\UpdateProductAvailabilityRequest;
use App\Http\Requests\UpdateProductRequest;
use App\Http\Resources\MenuCategoryResource;
use App\Http\Resources\ProductResource;
use App\Models\MenuCategory;
use App\Models\Product;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * La gestion del menu: lo que el restaurante ve y edita de su propia carta.
 *
 * Ninguna accion de aqui recibe un restaurant_id. El restaurante sale SIEMPRE
 * de la sesion (ver EnsureRestaurantAccount), asi que es imposible pedir o
 * tocar el menu de otro cambiando un numero en la URL. Es la misma regla que
 * ya se aplico con 'role' y con 'user_id': el servidor decide, no el cliente.
 */
class MenuController extends Controller
{
    /**
     * GET /api/restaurant/menu
     *
     * El menu completo: categorias con sus productos adentro.
     *
     * Trae TAMBIEN los productos agotados (is_available = false). Es al reves
     * que la carta publica a proposito: el cliente no debe ver lo que no hay,
     * pero el restaurante necesita verlo para volver a activarlo.
     */
    public function index(Request $request): JsonResponse
    {
        // El middleware ya cargo la relacion, asi que esto no vuelve a
        // consultar la base: Eloquent la tiene guardada en el mismo modelo.
        $restaurant = $request->user()->restaurant;

        $categories = $restaurant
            ->menuCategories()  // ya vienen ordenadas por sort_order
            ->with('products')  // products ya viene ordenada por sort_order
            ->get();

        // Los platos SIN categoria viajan aparte, en su propia lista.
        //
        // Existen de verdad, por dos caminos: al crear un plato se puede no
        // elegir categoria, y al BORRAR una categoria sus platos quedan
        // sueltos (no se borran, ver destroyCategory). Si no se devolvieran,
        // esos platos desaparecerian de la pantalla sin que nadie los haya
        // borrado: la peor clase de bug, porque es silencioso.
        $uncategorized = $restaurant->products()
            ->whereNull('menu_category_id')
            ->orderBy('sort_order')
            ->get();

        return response()->json([
            'categories' => MenuCategoryResource::collection($categories),
            'uncategorized' => ProductResource::collection($uncategorized),
        ]);
    }

    /**
     * POST /api/restaurant/menu/categories
     *
     * Crea una categoria del menu. Del body solo se usa el nombre
     * ("Entradas", "Postres"...): el restaurante dueno lo pone el servidor.
     */
    public function storeCategory(StoreMenuCategoryRequest $request): JsonResponse
    {
        $restaurant = $request->user()->restaurant;

        $category = new MenuCategory;

        // Campo por campo, nunca MenuCategory::create($request->all()).
        // 'restaurant_id' NO es fillable a proposito: se asigna desde la
        // sesion, igual que 'role' en User. Asi nadie crea categorias en el
        // menu de otro restaurante.
        $category->name = $request->validated('name');
        $category->restaurant_id = $restaurant->id;

        $sortOrder = $request->validated('sort_order');

        if ($sortOrder === null) {
            // Sin orden explicito, la nueva categoria va al final de las que
            // ya hay: es lo que el restaurante espera al agregar "Postres".
            $sortOrder = ((int) $restaurant->menuCategories()->max('sort_order')) + 1;
        }

        $category->sort_order = $sortOrder;
        $category->save();

        // Los productos van vacios pero PRESENTES: asi la app recibe siempre
        // la misma forma y no tiene que preguntar si la clave existe.
        $category->load('products');

        return response()->json([
            'category' => new MenuCategoryResource($category),
        ], 201);
    }

    /**
     * PUT /api/restaurant/menu/categories/{category}
     *
     * Renombra una categoria (y de paso deja reordenarla).
     */
    public function updateCategory(UpdateMenuCategoryRequest $request, int $category): JsonResponse
    {
        $restaurant = $request->user()->restaurant;

        // Sobre la relacion, como todo lo demas: la categoria de otro
        // restaurante responde 404 y no se puede ni mirar.
        $model = $restaurant->menuCategories()->findOrFail($category);

        $model->name = $request->validated('name');

        $sortOrder = $request->validated('sort_order');

        if ($sortOrder !== null) {
            $model->sort_order = $sortOrder;
        }

        $model->save();

        // Los productos van vacios pero PRESENTES, igual que al crear: la app
        // recibe siempre la misma forma y no pregunta si la clave existe.
        $model->load('products');

        return response()->json([
            'category' => new MenuCategoryResource($model),
        ]);
    }

    /**
     * DELETE /api/restaurant/menu/categories/{category}
     *
     * Borra una categoria. LOS PLATOS NO SE BORRAN: quedan sin categoria.
     *
     * Hay que desengancharlos A MANO, y esa es la parte que se olvida:
     * la llave foranea de 'products.menu_category_id' usa nullOnDelete, pero
     * eso solo dispara con un DELETE de verdad. El borrado de aca es SUAVE
     * (el modelo usa SoftDeletes, o sea un UPDATE), asi que la base no toca
     * nada y los platos quedarian apuntando a una categoria que ya no se
     * muestra: existirian, pero invisibles.
     *
     * Va en una transaccion para que no pueda quedar a medias: o se sueltan
     * los platos y se borra la categoria, o no pasa nada.
     */
    public function destroyCategory(Request $request, int $category): JsonResponse
    {
        $restaurant = $request->user()->restaurant;

        $model = $restaurant->menuCategories()->findOrFail($category);

        DB::transaction(function () use ($restaurant, $model): void {
            $restaurant->products()
                ->where('menu_category_id', $model->id)
                ->update(['menu_category_id' => null]);

            $model->delete();
        });

        return response()->json([
            'message' => 'Categoría eliminada. Sus platos quedaron sin categoría.',
        ]);
    }

    /**
     * POST /api/restaurant/menu/products
     *
     * Crea un plato. Nace DISPONIBLE (is_available = true): apagarlo cuando
     * se acaba es una accion aparte, la del toggle de la lista.
     */
    public function storeProduct(StoreProductRequest $request): JsonResponse
    {
        $restaurant = $request->user()->restaurant;

        $product = new Product;

        // Campo por campo otra vez. 'restaurant_id' sale de la sesion; de la
        // peticion solo entra lo que el restaurante realmente escribe.
        $product->name = $request->validated('name');
        $product->description = $request->validated('description');
        $product->price = $request->validated('price');
        $product->restaurant_id = $restaurant->id;

        // Un plato nuevo nace disponible. Se asigna EXPLICITO y no se deja
        // al default de la base por un detalle que muerde: despues de un
        // INSERT, Eloquent NO trae los valores que puso la base. El registro
        // queda en true, pero el modelo en memoria tiene el campo vacio y la
        // respuesta lo devolvia en null — la app mostraba "agotado" un plato
        // recien creado. Poniendolo aqui, lo que se guarda y lo que se
        // responde son el mismo valor.
        $product->is_available = true;

        // StoreProductRequest ya verifico que la categoria es de ESTE
        // restaurante. Si no mandaron ninguna, el plato queda sin clasificar.
        $product->menu_category_id = $request->validated('menu_category_id');

        $sortOrder = $request->validated('sort_order');

        if ($sortOrder === null) {
            // Al final de su categoria. Si va sin categoria, al final de los
            // que tampoco tienen, para que no se mezcle con los clasificados.
            $query = $restaurant->products();

            if ($product->menu_category_id === null) {
                $query->whereNull('menu_category_id');
            } else {
                $query->where('menu_category_id', $product->menu_category_id);
            }

            $sortOrder = ((int) $query->max('sort_order')) + 1;
        }

        $product->sort_order = $sortOrder;
        $product->save();

        return response()->json([
            'product' => new ProductResource($product),
        ], 201);
    }

    /**
     * PATCH /api/restaurant/menu/products/{product}/availability
     *
     * El toggle de la lista: el restaurante apaga un plato cuando se le
     * acaba sin borrarlo del menu. El cliente deja de verlo; el restaurante
     * lo sigue viendo para volver a prenderlo.
     */
    public function updateProductAvailability(
        UpdateProductAvailabilityRequest $request,
        int $product,
    ): JsonResponse {
        $restaurant = $request->user()->restaurant;

        // findOrFail SOBRE LA RELACION y no Product::findOrFail():
        // asi el plato de otro restaurante simplemente NO EXISTE para
        // nosotros y responde 404. No hay que comparar ids a mano, y de paso
        // no se filtra si ese plato existe en el menu de otro.
        $model = $restaurant->products()->findOrFail($product);

        $model->is_available = $request->validated('is_available');
        $model->save();

        return response()->json([
            'product' => new ProductResource($model),
        ]);
    }

    /**
     * PUT /api/restaurant/menu/products/{product}
     *
     * Edita un plato. El formulario de la app manda el plato completo, por
     * eso PUT y no PATCH: lo que llega es el estado final que quiere el
     * restaurante, no un cambio suelto.
     */
    public function updateProduct(UpdateProductRequest $request, int $product): JsonResponse
    {
        $restaurant = $request->user()->restaurant;

        // Igual que en el toggle: findOrFail sobre la relacion. El plato de
        // otro restaurante responde 404 y no se puede ni editar ni mirar.
        $model = $restaurant->products()->findOrFail($product);

        $validated = $request->validated();

        $model->name = $validated['name'];
        $model->price = $validated['price'];

        // array_key_exists y NO '$validated["description"] ?? null'. La
        // diferencia es real: si el campo no viene, se deja lo que estaba;
        // si viene en null, se borra. Con '??' los dos casos se ven iguales
        // y guardar sin tocar la descripcion la borraria sola.
        if (array_key_exists('description', $validated)) {
            $model->description = $validated['description'];
        }

        if (array_key_exists('menu_category_id', $validated)) {
            $model->menu_category_id = $validated['menu_category_id'];
        }

        if (array_key_exists('sort_order', $validated)) {
            $model->sort_order = $validated['sort_order'];
        }

        $model->save();

        return response()->json([
            'product' => new ProductResource($model),
        ]);
    }

    /**
     * DELETE /api/restaurant/menu/products/{product}
     *
     * Saca un plato del menu.
     *
     * Es un BORRADO SUAVE (el modelo usa SoftDeletes): la fila se queda en
     * la base con 'deleted_at' puesto, y desaparece de todas las consultas.
     *
     * Por que suave y no de verdad: los pedidos guardan que plato se pidio y
     * a que precio. Si borraramos la fila, el historial de pedidos quedaria
     * con huecos. Y si el restaurante se equivoca, se puede recuperar.
     */
    public function destroyProduct(Request $request, int $product): JsonResponse
    {
        $restaurant = $request->user()->restaurant;

        // Sobre la relacion, igual que el toggle y la edicion: el plato de
        // otro restaurante responde 404. Y uno ya borrado tambien, porque
        // SoftDeletes lo deja fuera de la consulta.
        $model = $restaurant->products()->findOrFail($product);

        $model->delete();

        return response()->json([
            'message' => 'Plato eliminado del menu.',
        ]);
    }
}
