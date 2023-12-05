import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:i18n_extension/i18n_widget.dart';

import 'package:myapplib/myapplib.dart';
import '../globals.dart';
import '../main.i18n.dart';

class EditProducts extends StatelessWidget {
  const EditProducts({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
        providers: [ChangeNotifierProvider.value(value: products)],
        child: Consumer<Products>(
          builder: (context, doc, child) => WillPopScope(
            onWillPop: () async {
              products.save();
              return true;
            },
            child: Scaffold(
              appBar: AppBar(
                backgroundColor: Theme.of(context).colorScheme.inversePrimary,
                title: Text('Products'.i18n),
              ),
              body: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: products.rows.length,
                      itemBuilder: (_, index) {
                        return _listItem(index, context);
                      },
                    ),
                  ),
                ],
              ),
              floatingActionButton: FloatingActionButton(
                onPressed: () async {
                  await products.editRow(
                      numRow: -1,
                      editFn: () async {
                        // await products.getArt();
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => ProductRow()),
                        );
                      });
                  if (products.editOk) {
                    // await products.getArt();
                  }
                  // bollaCarico.sort();
                },
                child: const Icon(Icons.add),
              ),
            ),
          ),
        ));
  }

  Widget _listItem(index, context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(width: 1, color: Colors.black26))),
      child: ListTile(
        onLongPress: () async {
          _editRow(index, context);
        },
        title: Text(
          "${products.rows[index]['id']} : ${products.rows[index]['name']}",
          style: const TextStyle(fontSize: 18),
        ),
        // subtitle: Text(
        //   "Carico ${tot_carico.toStringAsFixed(2)} ${integra()}Scarico ${tot_scarico.toStringAsFixed(2)}",
        //   style: TextStyle(color: color),
        // ),
        trailing: Wrap(
          spacing: 0,
          children: [
            IconButton(
              onPressed: () async {
                await products.removeRow(index, context: context);
              },
              icon: const Icon(Icons.delete),
            ),
            IconButton(
              onPressed: () async {
                _editRow(index, context);
              },
              icon: const Icon(Icons.edit),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editRow(index, context) async {
    products.editOk = false;
    await products.editRow(
      numRow: index,
      editFn: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ProductRow()),
        );
      },
    );
  }
}

class ProductRow extends StatelessWidget {
  ProductRow({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider.value(value: products)],
      child: I18n(
        child: Consumer<Products>(
        builder: (context, doc, child) => Scaffold(
          appBar: AppBar(
            title: Text('Products'.i18n),
          ),
          body: _form(context),
        ),
      ),
      ),
    );
  }

  Widget _form(context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: ReactiveForm(
        formGroup: products.fgRow,
        onWillPop: () async {
          products.editOk = false;
          return true;
          // if (!products.modified) return true;
          // return await alertBox(
          //   context,
          //   text: "Item modified, confirm?",
          //   buttons: ['No', 'Yes'],
          // );
        },
        child: SingleChildScrollView(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: ReactiveTextField<String>(
                      formControlName: 'id',
                      decoration: inputDecoration('ProductID'.i18n),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ReactiveTextField<String>(
                      formControlName: 'name',
                      decoration: inputDecoration('Product name'.i18n),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  submitButton(
                      // onOk: () async {
                      // var qt = bollaCarico.R('qta_int').value;
                      // bollaCarico.R('qta_int').value =
                      //     qt + bollaCarico.R('_new_int').value;
                      // bollaCarico.R('_new_int').value = 0.0;
                      // // bollaCarico.sort();
                      // }
                      ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

