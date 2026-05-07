from pathlib import Path
import numpy as np
import nibabel as nib


folder = Path(r"C:\Users\Cristina\megtusalen\L2\data\sources\fooof_py")

affine = np.array([
    [10.0,  0.0,  0.0,  -70.0],
    [ 0.0, 10.0,  0.0, -110.0],
    [ 0.0,  0.0, 10.0,  -70.0],
    [ 0.0,  0.0,  0.0,    1.0]
], dtype=float)

out_folder = folder
out_folder.mkdir(exist_ok=True)

for path in list(folder.glob("*.nii")) + list(folder.glob("*.nii.gz")):

    nii = nib.load(str(path))
    data = nii.get_fdata(dtype=np.float32)

    # Copy header, then update units
    header = nii.header.copy()
    header.set_xyzt_units(xyz="mm")
    header.set_data_dtype(np.float32)

    # Create new NIfTI with corrected affine
    fixed = nib.Nifti1Image(data, affine, header=header)

    # Explicitly set both qform and sform
    fixed.set_qform(affine, code=1)
    fixed.set_sform(affine, code=1)

    out_path = out_folder / path.name
    nib.save(fixed, str(out_path))

    print(f"Saved: {out_path}")